# Read-only aggregation layer for the admin Dashboard (PRD §3.6).
#
# Every sale metric counts only real revenue: kept (non-discarded), document_type
# "venta" and status "confirmada" — cotizaciones and anuladas are excluded. The
# reference date is injectable so "this month"/"today" are deterministic in specs.
class DashboardMetrics
  LOW_STOCK_THRESHOLD = 10

  def initialize(today: Date.current)
    @today = today
  end

  # --- Monthly metrics -------------------------------------------------------
  def monthly_sales_count = monthly_sales.count
  def monthly_sales_total = monthly_sales.sum(:total_usd)

  # --- Daily metrics ---------------------------------------------------------
  def daily_sales_count = daily_sales.count
  def daily_sales_total = daily_sales.sum(:total_usd)

  # --- Risk / liquidity ------------------------------------------------------
  def outstanding_ar = pending_installments.sum(:balance_usd)
  def overdue_count  = overdue_installments.count
  def overdue_total  = overdue_installments.sum(:balance_usd)

  # --- Top 5 products this month (by units sold) -----------------------------
  # Returns an ordered Array of [Product, units_sold].
  def top_products
    rows = SaleItem
           .joins(:sale)
           .merge(monthly_sales)
           .group(:product_id)
           .order(Arel.sql("SUM(sale_items.quantity) DESC"))
           .limit(5)
           .sum(:quantity)

    products = Product.where(id: rows.keys).index_by(&:id)
    rows.map { |product_id, units| [ products[product_id], units ] }
  end

  # --- Low stock alert -------------------------------------------------------
  def low_stock_products
    Product.kept.where(stock: ...LOW_STOCK_THRESHOLD).order(:stock)
  end

  # --- Temporal series for charts (zero-filled across the month) -------------
  def sales_count_by_day = series(monthly_sales.group("DATE(created_at)").count)
  def sales_total_by_day = series(monthly_sales.group("DATE(created_at)").sum(:total_usd))

  private

  attr_reader :today

  def confirmed_ventas
    Sale.kept.where(document_type: "venta", status: "confirmada")
  end

  def monthly_sales
    confirmed_ventas.where(created_at: today.all_month)
  end

  def daily_sales
    confirmed_ventas.where(created_at: today.all_day)
  end

  def pending_installments
    Installment.where(status: "pendiente")
  end

  def overdue_installments
    pending_installments.where(due_date: ...today)
  end

  # Fills every day of the current month so charts show a continuous axis.
  # `grouped` keys may be Date or String depending on the adapter — normalize.
  def series(grouped)
    normalized = grouped.transform_keys { |key| key.is_a?(Date) ? key : Date.parse(key.to_s) }
    (today.beginning_of_month..today.end_of_month).index_with do |day|
      normalized[day] || 0
    end
  end
end
