require "rails_helper"

RSpec.describe DashboardMetrics do
  let(:today)     { Date.new(2026, 6, 17) }
  let(:warehouse) { create(:warehouse) }
  let(:client)    { create(:client, :ruc_client) }
  let(:metrics)   { described_class.new(today: today) }

  # Helper: a confirmed venta with a given amount and creation timestamp.
  # Use midday in the app time zone so the synthetic created_at lands
  # unambiguously inside that day's window regardless of the host's TZ
  # (the service queries `today.all_day`/`all_month` in Time.zone).
  def venta(total:, on:, **attrs)
    create(:sale, :venta, client: client, warehouse: warehouse,
           subtotal_usd: total, total_usd: total,
           created_at: on.in_time_zone.noon, **attrs)
  end

  describe "monthly metrics" do
    before do
      venta(total: 100.00, on: today)                 # this month + today
      venta(total: 50.00,  on: today.beginning_of_month) # this month, not today
      venta(total: 999.00, on: today.prev_month)       # previous month — excluded
      # cotizacion and anulada must be excluded from revenue
      create(:sale, client: client, warehouse: warehouse,
             document_type: "cotizacion", total_usd: 777.00, created_at: today.to_time)
      create(:sale, :venta, :anulada, client: client, warehouse: warehouse,
             total_usd: 500.00, created_at: today.to_time)
    end

    it "counts only confirmed ventas in the current month" do
      expect(metrics.monthly_sales_count).to eq(2)
    end

    it "sums total_usd of confirmed ventas in the current month" do
      expect(metrics.monthly_sales_total).to eq(150.00)
    end
  end

  describe "daily metrics" do
    before do
      venta(total: 100.00, on: today)
      venta(total: 25.00,  on: today)
      venta(total: 50.00,  on: today - 1) # yesterday — excluded from daily
    end

    it "counts confirmed ventas created today" do
      expect(metrics.daily_sales_count).to eq(2)
    end

    it "sums total_usd of confirmed ventas created today" do
      expect(metrics.daily_sales_total).to eq(125.00)
    end
  end

  describe "accounts receivable / risk metrics" do
    let(:sale) { venta(total: 100.00, on: today) }

    before do
      create(:installment, sale: sale, installment_number: 1, status: "pendiente",
             amount_usd: 40.00, balance_usd: 40.00, due_date: today + 5)   # pending, not overdue
      create(:installment, sale: sale, installment_number: 2, status: "pendiente",
             amount_usd: 30.00, balance_usd: 30.00, due_date: today - 3)   # pending, overdue
      create(:installment, sale: sale, installment_number: 3, status: "pagada",
             amount_usd: 30.00, balance_usd: 0.00, due_date: today - 10)   # paid — excluded
    end

    it "sums outstanding balance across pending installments" do
      expect(metrics.outstanding_ar).to eq(70.00)
    end

    it "counts overdue pending installments (due_date in the past)" do
      expect(metrics.overdue_count).to eq(1)
    end

    it "sums the overdue balance" do
      expect(metrics.overdue_total).to eq(30.00)
    end
  end

  describe "cobrado del mes (payments received this month)" do
    let(:sale) { venta(total: 100.00, on: today) }
    let(:installment) do
      create(:installment, sale: sale, installment_number: 1, status: "pendiente",
             amount_usd: 100.00, balance_usd: 100.00, due_date: today + 5)
    end

    before do
      create(:amortization, installment: installment, amount_usd: 30.00,
             paid_at: today.in_time_zone.noon)                     # this month
      create(:amortization, installment: installment, amount_usd: 20.00,
             paid_at: today.beginning_of_month.in_time_zone.noon)  # this month
      create(:amortization, installment: installment, amount_usd: 99.00,
             paid_at: today.prev_month.in_time_zone.noon)          # previous month — excluded
    end

    it "sums amortizations paid in the current month" do
      expect(metrics.monthly_collected).to eq(50.00)
    end
  end

  describe "ticket promedio (average sale this month)" do
    it "divides monthly revenue by the number of confirmed ventas" do
      venta(total: 100.00, on: today)
      venta(total: 50.00,  on: today)
      expect(metrics.monthly_average_ticket).to eq(75.00)
    end

    it "is zero when there are no ventas this month" do
      expect(metrics.monthly_average_ticket).to eq(0)
    end
  end

  describe "vencimientos próximos (installments due within 7 days)" do
    let(:sale) { venta(total: 100.00, on: today) }

    before do
      create(:installment, sale: sale, installment_number: 1, status: "pendiente",
             amount_usd: 10.00, balance_usd: 10.00, due_date: today)      # due today — included
      create(:installment, sale: sale, installment_number: 2, status: "pendiente",
             amount_usd: 20.00, balance_usd: 20.00, due_date: today + 7)  # edge of window — included
      create(:installment, sale: sale, installment_number: 3, status: "pendiente",
             amount_usd: 30.00, balance_usd: 30.00, due_date: today + 8)  # just outside — excluded
      create(:installment, sale: sale, installment_number: 4, status: "pendiente",
             amount_usd: 40.00, balance_usd: 40.00, due_date: today - 1)  # overdue — excluded
      create(:installment, sale: sale, installment_number: 5, status: "pagada",
             amount_usd: 50.00, balance_usd: 0.00, due_date: today + 2)   # paid — excluded
    end

    it "lists pending installments due from today through 7 days out, ordered by due_date" do
      expect(metrics.upcoming_installments.map(&:installment_number)).to eq([ 1, 2 ])
    end

    it "sums the balance of upcoming installments" do
      expect(metrics.upcoming_total).to eq(30.00)
    end
  end

  describe "previous-period trends (percent change vs last month)" do
    it "computes the sales-total percent change vs the previous month" do
      venta(total: 100.00, on: today.prev_month)  # baseline: 100
      venta(total: 100.00, on: today)
      venta(total: 50.00,  on: today)             # current: 150
      # (150 - 100) / 100 * 100 = 50.0
      expect(metrics.monthly_sales_total_trend).to eq(50.0)
    end

    it "returns a negative percent change when revenue drops" do
      venta(total: 200.00, on: today.prev_month)  # baseline: 200
      venta(total: 150.00, on: today)             # current: 150
      # (150 - 200) / 200 * 100 = -25.0
      expect(metrics.monthly_sales_total_trend).to eq(-25.0)
    end

    it "returns nil when there is no previous-month baseline" do
      venta(total: 150.00, on: today)
      expect(metrics.monthly_sales_total_trend).to be_nil
    end

    it "computes the collected percent change vs the previous month" do
      prev_sale = venta(total: 100.00, on: today.prev_month)
      prev_inst = create(:installment, sale: prev_sale, installment_number: 1,
                         status: "pendiente", amount_usd: 100.00, balance_usd: 100.00,
                         due_date: today)
      create(:amortization, installment: prev_inst, amount_usd: 40.00,
             paid_at: today.prev_month.in_time_zone.noon)  # baseline: 40

      sale = venta(total: 100.00, on: today)
      inst = create(:installment, sale: sale, installment_number: 1, status: "pendiente",
                    amount_usd: 100.00, balance_usd: 100.00, due_date: today + 5)
      create(:amortization, installment: inst, amount_usd: 60.00,
             paid_at: today.in_time_zone.noon)             # current: 60
      # (60 - 40) / 40 * 100 = 50.0
      expect(metrics.monthly_collected_trend).to eq(50.0)
    end

    it "computes the average-ticket percent change vs the previous month" do
      venta(total: 100.00, on: today.prev_month)  # prev avg ticket: 100
      venta(total: 100.00, on: today)
      venta(total: 200.00, on: today)             # current avg ticket: 150
      # (150 - 100) / 100 * 100 = 50.0
      expect(metrics.monthly_average_ticket_trend).to eq(50.0)
    end
  end

  describe "top 5 products" do
    it "ranks products by units sold this month, descending, limited to 5" do
      products = (1..6).map { |i| create(:product, name: "P#{i}", warehouse: warehouse) }
      sale = venta(total: 10.00, on: today)
      # units: P1=1 ... P6=6, so the top 5 should be P6..P2 in that order
      products.each_with_index do |product, idx|
        create(:sale_item, sale: sale, product: product, quantity: idx + 1,
               unit_price_usd: 1.00, line_total_usd: (idx + 1).to_f)
      end

      ranking = metrics.top_products
      expect(ranking.size).to eq(5)
      expect(ranking.first).to eq([ products[5], 6 ]) # P6 with 6 units
      expect(ranking.map(&:last)).to eq([ 6, 5, 4, 3, 2 ])
    end
  end

  describe "low stock alert" do
    it "lists kept products with stock strictly below 10" do
      low  = create(:product, name: "Low", stock: 9, warehouse: warehouse)
      edge = create(:product, name: "Edge", stock: 10, warehouse: warehouse)
      high = create(:product, name: "High", stock: 50, warehouse: warehouse)

      result = metrics.low_stock_products
      expect(result).to include(low)
      expect(result).not_to include(edge, high)
    end
  end

  describe "temporal series (charts)" do
    before do
      venta(total: 100.00, on: today)
      venta(total: 20.00,  on: today)
      venta(total: 50.00,  on: today.beginning_of_month)
    end

    it "returns a count per day covering every day of the month (zero-filled)" do
      series = metrics.sales_count_by_day
      expect(series.size).to eq(today.end_of_month.day) # all days present
      expect(series[today]).to eq(2)
      expect(series[today.beginning_of_month]).to eq(1)
      expect(series[today - 1]).to eq(0) # a day with no sales is zero, not missing
    end

    it "returns a revenue sum per day (zero-filled)" do
      series = metrics.sales_total_by_day
      expect(series[today]).to eq(120.00)
      expect(series[today.beginning_of_month]).to eq(50.00)
      expect(series[today - 1]).to eq(0)
    end
  end
end
