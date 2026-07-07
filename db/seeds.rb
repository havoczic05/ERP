# This file should ensure the existence of records required to run the application in every environment
# (production, development, test). The code here is idempotent so it can be executed at any point.
#
# Structure:
#   1. Core records (warehouses, users) — idempotent, safe in ANY environment.
#   2. Demo catalog (products, clients) — idempotent by natural key (SKU / document_number).
#   3. Demo transactions (sales, cotizaciones, payments, annulments) — generated ONLY when the
#      sales table is empty, so re-running `db:seed` never duplicates correlatives.
#
# All transactional data is created through the real service objects (SaleCreationService,
# AmortizationCreationService, SaleAnnulmentService) so the generated data is internally
# consistent: correct correlatives, totals, stock decrements and installment plans.

require "bigdecimal"
require "bigdecimal/util"

# Deterministic RNG so re-seeding a fresh DB always produces the same demo dataset.
rng = Random.new(20260620)

# ---------------------------------------------------------------------------
# 0. Destructive reset (development / test only)
# ---------------------------------------------------------------------------
# Wipe and regenerate the whole demo dataset on every run, EXCEPT users (login
# accounts are preserved). Guarded to Rails.env.local? so production is never
# touched — there the idempotent `find_or_create_by` + sales guard below keep
# seeding safe. Deleted in FK-safe order (children before parents).
if Rails.env.local?
  Amortization.delete_all
  CreditNote.delete_all
  Installment.delete_all
  SaleItem.delete_all
  Sale.delete_all
  Product.delete_all
  Client.delete_all
  BankAccount.delete_all # child of company_settings — must go before its parent
  CompanySettings.delete_all
  Warehouse.delete_all
end

# ---------------------------------------------------------------------------
# 1. Core records
# ---------------------------------------------------------------------------

main_warehouse = Warehouse.find_or_create_by!(name: "Almacén Principal") do |w|
  w.location = "Lima, Perú"
end

north_warehouse = Warehouse.find_or_create_by!(name: "Almacén Norte") do |w|
  w.location = "Trujillo, Perú"
end

warehouses = [ main_warehouse, north_warehouse ]

# Idempotent user upsert: create the account if missing, and on every run
# (re)set role / password / active so the seeded credentials always work.
# find_or_create_by! only assigns the block attributes on create, which left a
# stale password on accounts that already existed from an earlier seed.
ensure_user = lambda do |email:, role:, password:|
  User.find_or_initialize_by(email: email).tap do |user|
    user.role     = role
    user.password = password
    user.active   = true
    user.save!
  end
end

admin = ensure_user.call(
  email:    "admin@erp.local",
  role:     "administrador",
  password: ENV.fetch("SEED_ADMIN_PASSWORD", "changeme123")
)

ensure_user.call(
  email:    "vendedor@erp.local",
  role:     "vendedor",
  password: ENV.fetch("SEED_VENDEDOR_PASSWORD", "changeme123")
)

# Company settings — singleton row. Fill every column so PDFs / headers render
# with real data instead of blanks.
CompanySettings.instance.update!(
  razon_social: "Electrodomésticos del Perú S.A.C.",
  ruc:          "20512345678",
  direccion:    "Av. Javier Prado Este 1234, San Isidro, Lima",
  telefono:     "014567890"
)

# ---------------------------------------------------------------------------
# Production guard
# ---------------------------------------------------------------------------
# Everything below (demo catalog + demo transactions) is development/test
# fixture data. In production we stop here so `db:seed` only creates the core
# records needed to start using the app: login users, warehouses and company
# settings — never the ~900 demo products / 200 clients / thousands of ventas.
# Set SEED_DEMO=true to force the full demo dataset in any environment.
unless Rails.env.local? || ENV["SEED_DEMO"] == "true"
  puts "Producción: core seeds listos (usuarios, almacenes, configuración). Data demo omitida."
  return
end

# ---------------------------------------------------------------------------
# 2. Demo catalog — products
# ---------------------------------------------------------------------------

# Brand → short SKU code. Electronics / home-appliances retailer (prices in USD).
BRANDS = {
  "Samsung"    => "SAM",
  "LG"         => "LGE",
  "Sony"       => "SNY",
  "Bosch"      => "BSH",
  "Philips"    => "PHI",
  "Panasonic"  => "PAN",
  "Whirlpool"  => "WHP",
  "Mabe"       => "MAB",
  "Electrolux" => "ELX",
  "Indurama"   => "IND",
  "Oster"      => "OST",
  "Xiaomi"     => "XMI",
  "HP"         => "HPQ",
  "Lenovo"     => "LNV",
  "TCL"        => "TCL"
}.freeze

# Product type → [SKU code, price floor, price ceiling] in USD.
PRODUCT_TYPES = [
  [ "Refrigeradora",      "REF", 380, 1300 ],
  [ "Televisor LED",      "TVL", 220, 1600 ],
  [ "Lavadora",           "LAV", 280, 1100 ],
  [ "Microondas",         "MIC", 70,  260 ],
  [ "Licuadora",          "LIC", 30,  140 ],
  [ "Cocina a gas",       "COC", 180, 720 ],
  [ "Aspiradora",         "ASP", 90,  430 ],
  [ "Ventilador",         "VEN", 25,  110 ],
  [ "Laptop",             "LAP", 380, 1800 ],
  [ "Impresora",          "IMP", 90,  520 ],
  [ "Aire acondicionado", "AIR", 320, 1400 ],
  [ "Congeladora",        "CON", 300, 950 ],
  [ "Plancha",            "PLA", 20,  90 ],
  [ "Hervidor",           "HER", 18,  75 ],
  [ "Parlante Bluetooth", "PAR", 35,  320 ],
  [ "Smartphone",         "SMT", 150, 1300 ],
  [ "Tablet",             "TAB", 120, 900 ],
  [ "Monitor",            "MON", 110, 650 ],
  [ "Audífonos",          "AUD", 25,  400 ],
  [ "Batidora",           "BAT", 35,  180 ]
].freeze

MODEL_LINES = %w[Pro Plus Max Lite Smart Eco Elite Prime One Neo].freeze

# Target catalog size. model × brand × type gives 10 × 15 × 20 = 3000 possible
# combos; we take the first PRODUCT_TARGET. Iterating model-outermost keeps every
# brand and product type represented within the first slice (the alternative,
# brand-outermost, would only surface the first ~5 brands). The per-index serial
# guarantees SKU uniqueness regardless of brand/type/model repetition.
# Stock starts high so the demo can absorb ~1000 ventas without hitting the
# service's stock gate. Distributed round-robin across warehouses.
PRODUCT_TARGET = 900
product_specs = []

MODEL_LINES.product(BRANDS.to_a, PRODUCT_TYPES).each_with_index do |(model, brand_pair, type), idx|
  break if product_specs.size >= PRODUCT_TARGET

  brand_name, brand_code       = brand_pair
  type_name, type_code, lo, hi = type

  serial = format("%04d", idx + 1)
  # Round to a "nice" .90 retail-looking price.
  price  = rng.rand(lo..hi).to_d.floor + 0.90.to_d

  product_specs << {
    sku:            "#{brand_code}-#{type_code}-#{serial}",
    name:           "#{type_name} #{brand_name} #{model} #{serial}",
    brand:          brand_name,
    base_price_usd: price,
    stock:          rng.rand(500..2000),
    warehouse:      warehouses[idx % warehouses.size]
  }
end

product_specs.each do |spec|
  Product.find_or_create_by!(sku: spec[:sku]) do |p|
    p.name           = spec[:name]
    p.brand          = spec[:brand]
    p.base_price_usd = spec[:base_price_usd]
    p.stock          = spec[:stock]
    p.warehouse      = spec[:warehouse]
  end
end

puts "Products in catalog: #{Product.kept.count}"

# ---------------------------------------------------------------------------
# 2b. Demo catalog — clients
# ---------------------------------------------------------------------------

FIRST_NAMES = %w[
  María José Carlos Ana Luis Rosa Jorge Carmen Pedro Lucía Miguel Elena
  Juan Patricia Roberto Sofía Manuel Gabriela Fernando Daniela
].freeze

LAST_NAMES = %w[
  García Rodríguez Flores Torres Ramírez Vargas Castillo Rojas Mendoza
  Quispe Huamán Chávez Díaz Reyes Salazar Cáceres Paredes Ríos Espinoza Núñez
].freeze

COMPANY_PREFIXES = %w[Comercial Distribuidora Importadora Inversiones Servicios Corporación Grupo Tecno].freeze
COMPANY_SUFFIXES = %w[SAC EIRL SRL SA].freeze

# [departamento, provincia, distrito] tuples for realistic Peruvian addresses.
LOCATIONS = [
  [ "Lima",         "Lima",       "Miraflores" ],
  [ "Lima",         "Lima",       "San Isidro" ],
  [ "Lima",         "Lima",       "Surco" ],
  [ "Lima",         "Lima",       "San Borja" ],
  [ "La Libertad",  "Trujillo",   "Trujillo" ],
  [ "Arequipa",     "Arequipa",   "Cercado" ],
  [ "Piura",        "Piura",      "Piura" ],
  [ "Cusco",        "Cusco",      "Wanchaq" ],
  [ "Lambayeque",   "Chiclayo",   "Chiclayo" ],
  [ "Junín",        "Huancayo",   "El Tambo" ]
].freeze

STREET_NAMES = [ "Av. Los Próceres", "Jr. San Martín", "Calle Las Begonias", "Av. Grau",
                 "Jr. Amazonas", "Av. La Marina", "Calle Bolívar", "Av. Brasil" ].freeze

# Returns a hash of location attributes for a client, drawn deterministically.
pick_location = lambda do
  departamento, provincia, distrito = LOCATIONS[rng.rand(LOCATIONS.size)]
  {
    departamento: departamento,
    provincia:    provincia,
    distrito:     distrito,
    direccion:    "#{STREET_NAMES[rng.rand(STREET_NAMES.size)]} #{rng.rand(100..1999)}"
  }
end

clients = []

# 130 individuals (DNI — 8 digits) + 70 businesses (RUC — 11 digits) = 200 clients.
# Document numbers are derived from the loop index so they are guaranteed unique
# (a rand-based scheme risks collisions at this volume).
130.times do |i|
  first = FIRST_NAMES[rng.rand(FIRST_NAMES.size)]
  last1 = LAST_NAMES[rng.rand(LAST_NAMES.size)]
  last2 = LAST_NAMES[rng.rand(LAST_NAMES.size)]
  doc   = format("%08d", 40_000_000 + i)

  loc = pick_location.call
  clients << Client.find_or_create_by!(document_number: doc) do |c|
    c.full_name     = "#{first} #{last1} #{last2}"
    c.document_type = "dni"
    c.phone         = "9#{format('%08d', rng.rand(0..99_999_999))}"
    c.departamento  = loc[:departamento]
    c.provincia     = loc[:provincia]
    c.distrito      = loc[:distrito]
    c.direccion     = loc[:direccion]
  end
end

70.times do |i|
  prefix = COMPANY_PREFIXES[rng.rand(COMPANY_PREFIXES.size)]
  word   = LAST_NAMES[rng.rand(LAST_NAMES.size)]
  suffix = COMPANY_SUFFIXES[rng.rand(COMPANY_SUFFIXES.size)]
  # Peru RUC: 11 digits, businesses start with "20".
  doc    = "20#{format('%09d', 100_000_000 + i)}"

  loc = pick_location.call
  clients << Client.find_or_create_by!(document_number: doc) do |c|
    c.full_name     = "#{prefix} #{word} #{suffix}"
    c.document_type = "ruc"
    c.phone         = "01#{format('%07d', rng.rand(0..9_999_999))}"
    c.departamento  = loc[:departamento]
    c.provincia     = loc[:provincia]
    c.distrito      = loc[:distrito]
    c.direccion     = loc[:direccion]
  end
end

puts "Clients registered: #{Client.kept.count}"

# ---------------------------------------------------------------------------
# 3. Demo transactions — sales, cotizaciones, payments, annulments
# ---------------------------------------------------------------------------
# Guard: only generate when there are no sales yet. Correlatives auto-increment,
# so re-running would otherwise pile up duplicate-looking demo documents.

if Sale.count.positive?
  puts "Sales already present (#{Sale.count}) — skipping demo transaction generation."
else
  all_products          = Product.kept.to_a
  products_by_warehouse = all_products.group_by(&:warehouse_id)

  # Builds a random set of line items drawn from a single warehouse, respecting
  # current stock so venta stock-gates pass. Returns [warehouse_id, items].
  build_items = lambda do |for_venta|
    warehouse_id = warehouses[rng.rand(warehouses.size)].id
    pool = products_by_warehouse[warehouse_id]
             .select { |p| p.stock >= 5 }
             .sample(rng.rand(1..4), random: rng)

    items = pool.map do |product|
      max_qty  = for_venta ? [ product.stock, 4 ].min : 4
      quantity = rng.rand(1..[ max_qty, 1 ].max)
      discount = [ 0, 0, 0, 5, 10 ][rng.rand(5)] # occasional negotiated discount
      unit     = (product.base_price_usd * (100 - discount) / 100).round(2)
      unit     = product.base_price_usd if unit <= 0
      { product_id: product.id, quantity: quantity, unit_price_usd: unit }
    end

    [ warehouse_id, items ]
  end

  # Spreads a document's created_at over the last ~180 days for a realistic timeline.
  backdate = lambda do |sale, days_ago|
    ts = days_ago.days.ago
    sale.update_columns(
      created_at:   ts,
      updated_at:   ts,
      confirmed_at: (sale.venta? ? ts : nil)
    )
  end

  # Demo volume targets and the timeline window (~5 months).
  VENTAS_TARGET     = 9000
  COTIZACIONES_COUNT = 120
  SALES_WINDOW_DAYS = 150

  ventas       = []
  cotizaciones = []
  failures     = 0

  # --- 1000 ventas over the last ~5 months --------------------------------
  # Loop until the target is met (the stock gate can occasionally reject a
  # draw). The attempt cap is a safety valve against an unexpected stall.
  attempts = 0
  while ventas.size < VENTAS_TARGET && attempts < VENTAS_TARGET * 2
    attempts += 1
    warehouse_id, items = build_items.call(true)
    next if items.empty?

    result = SaleCreationService.call(
      client_id:        clients[rng.rand(clients.size)].id,
      warehouse_id:     warehouse_id,
      document_type:    "venta",
      items:            items,
      num_installments: [ 1, 1, 2, 3, 6 ][rng.rand(5)],
      interval_days:    30,
      notes:            nil
    )

    if result.success?
      backdate.call(result.sale, rng.rand(0..SALES_WINDOW_DAYS))
      ventas << result.sale
      puts "  ... #{ventas.size} ventas" if (ventas.size % 100).zero?
    else
      failures += 1
    end
  end

  # --- cotizaciones -------------------------------------------------------
  COTIZACIONES_COUNT.times do
    warehouse_id, items = build_items.call(false)
    next if items.empty?

    result = SaleCreationService.call(
      client_id:     clients[rng.rand(clients.size)].id,
      warehouse_id:  warehouse_id,
      document_type: "cotizacion",
      items:         items,
      notes:         "Cotización válida por 15 días."
    )

    if result.success?
      backdate.call(result.sale, rng.rand(0..SALES_WINDOW_DAYS))
      cotizaciones << result.sale
    else
      failures += 1
    end
  end

  # --- Convert ~15 cotizaciones into ventas -------------------------------
  cotizaciones.sample(15, random: rng).each do |cotizacion|
    result = SaleCreationService.convert(
      cotizacion,
      num_installments: [ 1, 2, 3 ][rng.rand(3)],
      interval_days:    30
    )
    if result.success?
      backdate.call(result.sale, rng.rand(0..SALES_WINDOW_DAYS))
      ventas << result.sale
    else
      failures += 1
    end
  end

  # --- Anchor each sale's installment schedule to its start date ------------
  # SaleCreationService anchors due_dates to Date.today (correct for real-time
  # sales). For backdated demo ventas that would put every cuota in the future.
  # Re-anchor to the sale's start (its backdated created_at) so the schedule
  # shifts coherently into the past: earlier cuotas fall due first (some already
  # overdue), later ones remain pending — ALWAYS in installment_number order.
  INSTALLMENT_INTERVAL_DAYS = 30
  ventas.each do |venta|
    start_date = venta.created_at.to_date
    venta.installments.order(:installment_number).each do |inst|
      inst.update_columns(
        due_date: start_date + (inst.installment_number * INSTALLMENT_INTERVAL_DAYS).days
      )
    end
  end

  # --- Pay installments on ~40% of ventas (full first cuota, sometimes more) ---
  # Payment dates are anchored to each sale's own timeline so the demo data is
  # chronologically possible: a cuota is paid around its due_date, NEVER before
  # the sale itself, NEVER in the future, and ALWAYS after the previous cuota's
  # payment (cuota 1 settles before cuota 2).
  today = Date.current
  paid_sample_size = (ventas.size * 0.40).round
  ventas.sample(paid_sample_size, random: rng).each do |venta|
    start_date = venta.created_at.to_date
    last_paid  = start_date
    hour_base  = rng.rand(8..16)
    venta.installments.where(status: "pendiente").order(:installment_number).first(2).each do |installment|
      break if rng.rand(100) < 25 # leave some cuotas open for a realistic mix

      # Pay near the due date (sometimes a few days early), clamped so the date
      # is never before the previous payment, never before the sale, and never
      # in the future.
      target  = installment.due_date - rng.rand(0..5).days
      paid_on = [ [ target, last_paid ].max, today ].min
      last_paid = paid_on

      # +installment_number keeps same-day payments ordered by cuota; clamp to
      # "now" so a payment dated today never lands past the current wall-clock.
      paid_ts = paid_on.in_time_zone.change(hour: hour_base) + installment.installment_number.hours
      AmortizationCreationService.call(
        installment,
        amount:  installment.balance_usd,
        paid_at: [ paid_ts, Time.current ].min
      )
    end
  end

  # --- Annul ~2% of ventas (creates credit notes, restores stock) ---------
  annul_sample_size = (ventas.size * 0.02).round
  ventas.sample(annul_sample_size, random: rng).each do |venta|
    SaleAnnulmentService.call(venta.reload, admin)
  end

  puts "Ventas created:        #{Sale.venta.count}"
  puts "Cotizaciones created:  #{Sale.cotizacion.count}"
  puts "Installments:          #{Installment.count} (#{Installment.where(status: 'pagada').count} pagadas)"
  puts "Amortizations:         #{Amortization.count}"
  puts "Credit notes:          #{CreditNote.count}"
  puts "Skipped (stock/other): #{failures}" if failures.positive?
end

puts "Seed complete."
