# Read-only aggregation layer for the admin Dashboard (PRD §3.6).
#
# Every sale metric counts only real revenue: kept (non-discarded), document_type
# "venta" and status "confirmada" — cotizaciones and anuladas are excluded. The
# reference date is injectable so "this month"/"today" are deterministic in specs.
class DashboardMetrics
  LOW_STOCK_THRESHOLD = 10
  UPCOMING_WINDOW_DAYS = 7

  # Time windows the temporal charts can switch between. "month" is the default
  # and the only one the KPIs use; the others only reshape the chart series.
  VALID_CHART_RANGES = %w[month 30d 7d].freeze
  DEFAULT_CHART_RANGE = "month"

  # The sanitized chart range in effect — the view reads this to highlight the
  # matching toggle option, so it always agrees with the data actually shown.
  attr_reader :chart_range

  def initialize(today: Date.current, chart_range: DEFAULT_CHART_RANGE)
    @today = today
    @chart_range = VALID_CHART_RANGES.include?(chart_range.to_s) ? chart_range.to_s : DEFAULT_CHART_RANGE
  end

  # --- Monthly metrics -------------------------------------------------------
  def monthly_sales_count = monthly_sales.count
  def monthly_sales_total = monthly_sales.sum(:total_usd)

  # Average sale amount this month (revenue / number of ventas). Zero when
  # there are no ventas so the KPI card never divides by zero.
  def monthly_average_ticket = average_ticket(monthly_sales)

  # Payments actually received this month (amortizations, by paid_at).
  def monthly_collected = monthly_amortizations.sum(:amount_usd)

  # --- Daily metrics ---------------------------------------------------------
  def daily_sales_count = daily_sales.count
  def daily_sales_total = daily_sales.sum(:total_usd)

  # --- Risk / liquidity ------------------------------------------------------
  def outstanding_ar = pending_installments.sum(:balance_usd)
  def overdue_count  = overdue_installments.count
  def overdue_total  = overdue_installments.sum(:balance_usd)

  # --- Upcoming due installments (next 7 days, inclusive of today) -----------
  # Pending installments coming due — drives the "Vencimientos de la semana"
  # panel. Overdue and paid installments are excluded.
  def upcoming_installments
    pending_installments
      .where(due_date: today..(today + UPCOMING_WINDOW_DAYS))
      .includes(sale: :client)
      .order(:due_date)
  end

  def upcoming_total = upcoming_installments.sum(:balance_usd)

  # --- Previous-period trends (percent change vs last month, for badges) -----
  # Each returns a Float percentage (1 decimal), or nil when the previous month
  # has no baseline to compare against.
  def monthly_sales_total_trend
    percent_change(monthly_sales_total, prev_monthly_sales.sum(:total_usd))
  end

  def monthly_collected_trend
    percent_change(monthly_collected, prev_monthly_amortizations.sum(:amount_usd))
  end

  def monthly_average_ticket_trend
    percent_change(monthly_average_ticket, average_ticket(prev_monthly_sales))
  end

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

  # --- Temporal series for charts (zero-filled across the selected range) ----
  def sales_count_by_day = series(chart_sales.group("DATE(created_at)").count)
  def sales_total_by_day = series(chart_sales.group("DATE(created_at)").sum(:total_usd))

  private

  attr_reader :today

  def confirmed_ventas
    Sale.kept.where(document_type: "venta", status: "confirmada")
  end

  def monthly_sales
    confirmed_ventas.where(created_at: today.all_month)
  end

  # Confirmed ventas within the currently selected chart window.
  def chart_sales
    confirmed_ventas.where(created_at: chart_window)
  end

  # The calendar days the chart spans, inclusive of today. Drives both the
  # DB window and the zero-fill so every day shows even with no sales.
  def chart_days
    case chart_range
    when "7d"  then (today - 6)..today
    when "30d" then (today - 29)..today
    else            today.beginning_of_month..today.end_of_month
    end
  end

  # Time range covering `chart_days`, in the app time zone (created_at is a
  # timestamp, so day boundaries must be zoned to match the KPI queries).
  def chart_window
    chart_days.first.in_time_zone.beginning_of_day..chart_days.last.in_time_zone.end_of_day
  end

  def prev_monthly_sales
    confirmed_ventas.where(created_at: today.prev_month.all_month)
  end

  def daily_sales
    confirmed_ventas.where(created_at: today.all_day)
  end

  def monthly_amortizations
    Amortization.where(paid_at: today.all_month)
  end

  def prev_monthly_amortizations
    Amortization.where(paid_at: today.prev_month.all_month)
  end

  def pending_installments
    Installment.where(status: "pendiente")
  end

  def overdue_installments
    pending_installments.where(due_date: ...today)
  end

  # Revenue / number of ventas for a given sales relation. Zero when empty.
  def average_ticket(sales)
    count = sales.count
    return BigDecimal("0") if count.zero?

    sales.sum(:total_usd) / count
  end

  # Percent change of `current` relative to `previous`. Nil when there is no
  # baseline (previous is zero), signalling "no comparison" to the view.
  def percent_change(current, previous)
    previous = previous.to_f
    return nil if previous.zero?

    (((current.to_f - previous) / previous) * 100).round(1)
  end

  # Fills every day of the selected range so charts show a continuous axis.
  # `grouped` keys may be Date or String depending on the adapter — normalize.
  def series(grouped)
    normalized = grouped.transform_keys { |key| key.is_a?(Date) ? key : Date.parse(key.to_s) }
    chart_days.index_with { |day| normalized[day] || 0 }
  end
end
