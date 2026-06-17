require "rails_helper"

RSpec.describe DashboardMetrics do
  let(:today)     { Date.new(2026, 6, 17) }
  let(:warehouse) { create(:warehouse) }
  let(:client)    { create(:client, :ruc_client) }
  let(:metrics)   { described_class.new(today: today) }

  # Helper: a confirmed venta with a given amount and creation timestamp.
  def venta(total:, on:, **attrs)
    create(:sale, :venta, client: client, warehouse: warehouse,
           subtotal_usd: total, total_usd: total,
           created_at: on.to_time, **attrs)
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
