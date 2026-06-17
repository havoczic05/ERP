# SaleCreationService — creates a Sale (cotizacion or venta) transactionally.
#
# Concurrency strategy:
#   Products are loaded without a scope-level lock to avoid leaking FOR UPDATE
#   into subsequent AR validation queries. Instead, individual product rows are
#   locked with #with_lock (SELECT ... FOR UPDATE on a single row) in ascending
#   id order inside the transaction, which prevents deadlocks.
#
# Returns a Result PORO:  result.success? / result.sale / result.errors
class SaleCreationService
  MAX_CORRELATIVE_RETRIES = 3

  CORRELATIVE_PREFIX = {
    "cotizacion" => "COT",
    "venta"      => "VTA"
  }.freeze

  def self.call(params)
    new(params).call
  end

  def initialize(params)
    @params = params
  end

  def call
    @stock_errors = []

    ActiveRecord::Base.transaction do
      items_data = Array(@params[:items])

      # Step 1: validate inputs (items present, quantities > 0)
      if items_data.empty?
        @stock_errors = [ "At least one line item is required" ]
        raise ActiveRecord::Rollback
      end

      items_data.each do |item|
        qty = item[:quantity].to_i
        if qty <= 0
          @stock_errors = [ "Item quantity must be greater than 0" ]
          raise ActiveRecord::Rollback
        end
      end

      product_ids = items_data.map { |i| i[:product_id].to_i }.sort  # ascending id order

      # Step 2: load products (plain SELECT — no scope-level lock to avoid FOR UPDATE leaking
      # into AR's belongs_to validation queries).
      products = Product.where(id: product_ids).order(:id).to_a

      # Validate all products exist
      if products.size != product_ids.uniq.size
        @stock_errors = [ "One or more products do not exist" ]
        raise ActiveRecord::Rollback
      end

      products_by_id = products.index_by(&:id)

      document_type = @params[:document_type].to_s

      # Step 3: lock each product row individually in id-ascending order (deadlock-free),
      # then check stock gate for venta.
      locked_products_by_id = {}
      products.sort_by(&:id).each do |product|
        # with_lock issues SELECT ... FOR UPDATE on just this row, then yields
        product.with_lock do
          locked_products_by_id[product.id] = product

          if document_type == "venta"
            qty_for_product = items_data
                              .select { |i| i[:product_id].to_i == product.id }
                              .sum { |i| i[:quantity].to_i }

            if qty_for_product > product.stock
              @stock_errors << "Insufficient stock for #{product.name}: available #{product.stock}, requested #{qty_for_product}"
            end
          end
        end
      end

      unless @stock_errors.empty?
        raise ActiveRecord::Rollback
      end

      # Step 4: build Sale and SaleItems, compute totals
      subtotal = BigDecimal("0")
      sale_items_attrs = []

      items_data.each do |item|
        product    = products_by_id[item[:product_id].to_i]
        qty        = item[:quantity].to_i
        unit_price = BigDecimal(item[:unit_price_usd].to_s)
        line_total = unit_price * qty

        subtotal += line_total

        sale_items_attrs << {
          product_id:     product.id,
          quantity:       qty,
          unit_price_usd: unit_price,
          line_total_usd: line_total
        }
      end

      sale = Sale.new(
        client_id:     @params[:client_id],
        warehouse_id:  @params[:warehouse_id],
        document_type: document_type,
        status:        "confirmada",
        notes:         @params[:notes],
        tax_usd:       0.00,
        subtotal_usd:  subtotal,
        total_usd:     subtotal   # tax = 0 in v1
      )

      # Step 5: generate unique correlative (MAX+1 per type, rescue RecordNotUnique + retry)
      sale.correlative = generate_correlative_with_retry(document_type)

      sale.save!

      sale_items_attrs.each do |attrs|
        sale.sale_items.create!(attrs)
      end

      # Step 6: stock decrement (venta only) — re-lock individually in id-ascending order
      if document_type == "venta"
        items_data.sort_by { |i| i[:product_id].to_i }.each do |item|
          product = products_by_id[item[:product_id].to_i]
          qty     = item[:quantity].to_i
          product.with_lock do
            product.update_column(:stock, product.stock - qty)
          end
        end
      end

      # Step 7: generate installments (venta only); assert SUM == total
      if document_type == "venta"
        apply_venta_installments!(sale)
      end

      return Result.success(sale)
    end

    # ActiveRecord::Rollback was raised — return failure
    build_failure_result
  rescue ActiveRecord::RecordInvalid => e
    build_failure_result([ e.message ])
  rescue ActiveRecord::StatementInvalid => e
    build_failure_result([ e.message ])
  end

  # ---------------------------------------------------------------------------
  # Shared venta effects — stock gate + decrement + installment generation.
  # Used by both the creation (venta path) and the conversion flow.
  # Call this inside an open transaction after the Sale record already exists
  # and its sale_items are persisted.
  # ---------------------------------------------------------------------------
  def apply_venta_effects!(sale)
    product_ids = sale.sale_items.pluck(:product_id).sort

    stock_errors = []

    # Lock each product row individually in id-ascending order
    products_by_id = {}
    product_ids.each do |pid|
      product = Product.find(pid)
      product.with_lock do
        products_by_id[pid] = product

        qty = sale.sale_items.find { |si| si.product_id == pid }&.quantity ||
              sale.sale_items.where(product_id: pid).sum(:quantity)

        if qty > product.stock
          stock_errors << "Insufficient stock for #{product.name}: available #{product.stock}, requested #{qty}"
        end
      end
    end

    unless stock_errors.empty?
      raise SaleCreationService::InsufficientStockError, stock_errors.join("; ")
    end

    # Decrement stock
    sale.sale_items.each do |item|
      product = products_by_id[item.product_id]
      product.with_lock do
        product.update_column(:stock, product.stock - item.quantity)
      end
    end

    # Generate installments
    apply_venta_installments!(sale)
  end

  # ---------------------------------------------------------------------------
  # Convert a cotizacion to a new venta.
  # Returns a Result PORO.
  # ---------------------------------------------------------------------------
  def self.convert(cotizacion, params)
    new(params).convert_from(cotizacion)
  end

  def convert_from(cotizacion)
    # Guard: this is already a venta
    if cotizacion.venta?
      return Result.failure(cotizacion, [ "This document is already a venta" ])
    end

    # Guard: already converted (a venta referencing this cotizacion exists)
    if Sale.where(source_cotizacion_id: cotizacion.id).exists?
      return Result.failure(cotizacion, [ "This cotizacion has already been converted to a venta" ])
    end

    @stock_errors = []

    ActiveRecord::Base.transaction do
      # Build the new venta from cotizacion data
      venta = Sale.new(
        client_id:            cotizacion.client_id,
        warehouse_id:         cotizacion.warehouse_id,
        document_type:        "venta",
        status:               "confirmada",
        notes:                cotizacion.notes,
        tax_usd:              0.00,
        subtotal_usd:         cotizacion.subtotal_usd,
        total_usd:            cotizacion.total_usd,
        source_cotizacion_id: cotizacion.id
      )

      venta.correlative = generate_correlative_with_retry("venta")
      venta.save!

      # Copy sale items from cotizacion
      cotizacion.sale_items.each do |item|
        venta.sale_items.create!(
          product_id:     item.product_id,
          quantity:       item.quantity,
          unit_price_usd: item.unit_price_usd,
          line_total_usd: item.line_total_usd
        )
      end

      # Reload to get freshly persisted sale_items
      venta.reload

      # Set installment params from conversion params
      @num_installments_override = @params[:num_installments].to_i
      @num_installments_override = 1 if @num_installments_override < 1
      @interval_days_override    = @params[:interval_days].to_i
      @interval_days_override    = 30 if @interval_days_override <= 0

      # Apply venta effects (stock gate + decrement + installments)
      apply_venta_effects!(venta)

      return Result.success(venta)
    end

    build_failure_result
  rescue SaleCreationService::InsufficientStockError => e
    build_failure_result([ e.message ])
  rescue ActiveRecord::RecordInvalid => e
    build_failure_result([ e.message ])
  rescue ActiveRecord::StatementInvalid => e
    build_failure_result([ e.message ])
  end

  # Custom error raised inside apply_venta_effects! when stock is insufficient.
  class InsufficientStockError < StandardError; end

  # ---------------------------------------------------------------------------
  private
  # ---------------------------------------------------------------------------

  def generate_correlative_with_retry(document_type)
    retries = 0
    begin
      generate_correlative(document_type)
    rescue ActiveRecord::RecordNotUnique
      retries += 1
      raise if retries >= MAX_CORRELATIVE_RETRIES
      retry
    end
  end

  # Returns the next sequential correlative for the given document_type.
  # Uses pluck + Ruby max to avoid FOR UPDATE incompatibility with aggregate funcs.
  def generate_correlative(document_type)
    prefix = CORRELATIVE_PREFIX.fetch(document_type, "DOC")
    existing_nums = Sale.where("correlative LIKE ?", "#{prefix}-%")
                        .pluck(:correlative)
                        .map { |c| c.delete_prefix("#{prefix}-").to_i }
    next_num = (existing_nums.max || 0) + 1
    "#{prefix}-#{format('%05d', next_num)}"
  end

  def apply_venta_installments!(sale)
    num      = (@num_installments_override || @params[:num_installments].to_i)
    num      = 1 if num < 1
    interval = (@interval_days_override || @params[:interval_days].to_i)
    interval = 30 if interval <= 0

    total = BigDecimal(sale.total_usd.to_s)

    base_amount = (total / num).round(2, :truncate)
    last_amount = total - base_amount * (num - 1)

    installment_amounts = Array.new(num, base_amount)
    installment_amounts[num - 1] = last_amount

    # Assert SUM == total before persisting
    actual_sum = installment_amounts.sum
    unless actual_sum == total
      @stock_errors = [ "Installment sum mismatch: #{actual_sum} != #{total}" ]
      raise ActiveRecord::Rollback
    end

    installment_amounts.each_with_index do |amount, index|
      number   = index + 1
      due_date = Date.today + (number * interval).days

      sale.installments.create!(
        installment_number: number,
        amount_usd:         amount,
        balance_usd:        amount,
        due_date:           due_date,
        status:             "pendiente"
      )
    end
  end

  def build_failure_result(extra_errors = [])
    errors = Array(@stock_errors) + Array(extra_errors)
    errors = [ "Sale could not be created" ] if errors.empty?
    Result.failure(nil, errors)
  end
end
