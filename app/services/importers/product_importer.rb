# Importers::ProductImporter — maps CSV/XLSX rows to Product records.
#
# Expected CSV/XLSX headers (must match ProductsController::CSV_HEADERS):
#   SKU, Nombre, Marca, Almacén, Stock, Precio base USD
#
# Per-row behavior:
#   - Duplicate check by SKU against Product.kept (case-sensitive, exact match after trim).
#   - Warehouse resolved by NAME (trimmed, case-insensitive) — unresolvable → row error.
#   - Validates via Product model; invalid attrs → row error.
#   - Partial save: each row is saved independently (no file-level transaction).
module Importers
  class ProductImporter < BaseImporter
    # Error messages (Spanish, hardcoded)
    MSG_SKU_DUPLICATE     = "SKU duplicado".freeze
    MSG_WAREHOUSE_MISSING = "Almacén no encontrado".freeze

    private

    def process_row(hash, fila, report)
      sku  = hash["SKU"].to_s.strip
      name = hash["Nombre"].to_s.strip

      # Duplicate check — by SKU among kept products
      if Product.kept.where(sku: sku).exists?
        report.add_duplicate(fila: fila, razon: MSG_SKU_DUPLICATE)
        return
      end

      # Warehouse resolution by trimmed case-insensitive name
      warehouse_name = hash["Almacén"].to_s.strip
      warehouse = Warehouse.where("LOWER(name) = ?", warehouse_name.downcase).first

      unless warehouse
        report.add_invalid(fila: fila, errores: [ MSG_WAREHOUSE_MISSING ])
        return
      end

      # Build and attempt to save
      product = Product.new(
        sku:           sku,
        name:          name,
        brand:         hash["Marca"].to_s.strip,
        warehouse:     warehouse,
        stock:         parse_numeric(hash["Stock"]),
        base_price_usd: parse_numeric(hash["Precio base USD"])
      )

      if product.save
        report.add_created(fila: fila)
      else
        report.add_invalid(fila: fila, errores: product.errors.full_messages)
      end
    end

    # Accepts Numeric (from xlsx typed cells) or String (from csv).
    # Returns the value as-is when already Numeric; parses string to Numeric otherwise.
    # Leading-zero loss from Excel is intentional and unrecoverable — those rows
    # will surface as bad-length validation errors, which is acceptable behaviour.
    def parse_numeric(val)
      return val if val.is_a?(Numeric)
      str = val.to_s.strip
      return nil if str.empty?
      str.include?(".") ? str.to_f : str.to_i
    end
  end
end
