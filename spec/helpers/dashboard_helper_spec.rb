require 'rails_helper'

RSpec.describe DashboardHelper, type: :helper do
  describe '#trend_badge' do
    it 'renders nothing when there is no baseline (nil)' do
      expect(helper.trend_badge(nil)).to be_nil
    end

    it 'renders an up badge in green for a positive change' do
      result = helper.trend_badge(12.5)
      expect(result).to include('trend--up')
      expect(result).to include('▲')
      expect(result).to include('12.5%')
    end

    it 'renders a down badge in red for a negative change (magnitude only)' do
      result = helper.trend_badge(-8.0)
      expect(result).to include('trend--down')
      expect(result).to include('▼')
      expect(result).to include('8.0%')
      expect(result).not_to include('-8.0%')
    end

    it 'renders a flat badge for no change' do
      result = helper.trend_badge(0.0)
      expect(result).to include('trend--flat')
      expect(result).to include('0.0%')
    end

    it 'describes the comparison for screen readers' do
      result = helper.trend_badge(12.5)
      expect(result).to include('vs. el mes pasado')
    end
  end

  describe '#chart_range_toggle' do
    it 'renders a link per range option' do
      html = helper.chart_range_toggle('month')
      expect(html).to include('range-opt')
      expect(html).to include('Mes')
      expect(html).to include('30 días')
      expect(html).to include('7 días')
    end

    it 'marks the active range with a modifier class and aria-current' do
      html = helper.chart_range_toggle('7d')
      expect(html).to include('range-opt--active')
      expect(html).to include('aria-current="true"')
    end

    it 'links each option back to the dashboard with a range param' do
      html = helper.chart_range_toggle('month')
      expect(html).to include('range=7d')
      expect(html).to include('range=30d')
      expect(html).to include('range=month')
    end
  end

  describe '#kpi_currency' do
    it 'renders the amount with a smaller, lighter USD unit span before it' do
      html = helper.kpi_currency(1234.5)
      expect(html).to include('kpi-unit')
      expect(html).to include('USD')
      expect(html).to include('1,234.50')
    end
  end

  describe '#area_chart_svg' do
    let(:count_series) do
      {
        Date.new(2026, 6, 1) => 0,
        Date.new(2026, 6, 2) => 3,
        Date.new(2026, 6, 3) => 1,
        Date.new(2026, 6, 4) => 0,
        Date.new(2026, 6, 5) => 5
      }
    end

    it 'renders a single line path connecting the data points' do
      result = helper.area_chart_svg(count_series, label: 'Ventas por día')
      expect(result.scan('class="chart-line"').size).to eq(1)
    end

    it 'renders a gradient-filled area referencing a unique gradient id' do
      result = helper.area_chart_svg(count_series, label: 'Ventas por día')
      expect(result).to include('<linearGradient')
      expect(result).to include('class="chart-area"')
      expect(result).to include('fill="url(#area-grad-ventas-por-dia)"')
    end

    it 'renders axis text labels (days and value scale)' do
      result = helper.area_chart_svg(count_series, label: 'Ventas por día')
      expect(result).to include('<text')
      expect(result).to include('chart-axis')
    end

    it 'is a responsive svg (no preserveAspectRatio="none" that would distort text)' do
      result = helper.area_chart_svg(count_series, label: 'Ventas por día')
      expect(result).not_to include('preserveAspectRatio="none"')
    end

    it 'keeps the accessible role and aria-label' do
      result = helper.area_chart_svg(count_series, label: 'Ventas por día del mes')
      expect(result).to include('role="img"')
      expect(result).to include('aria-label="Ventas por día del mes"')
    end

    it 'formats count tooltips in Spanish with singular/plural' do
      result = helper.area_chart_svg(count_series, label: 'x', format: :count)
      expect(result).to include('<title>02/06 — 3 ventas</title>')
      expect(result).to include('<title>03/06 — 1 venta</title>')
    end

    it 'formats money y-axis labels as plain delimited numbers (no USD unit)' do
      money_series = { Date.new(2026, 6, 2) => 1250.5, Date.new(2026, 6, 3) => 0 }
      result = helper.area_chart_svg(money_series, label: 'x', format: :money)
      expect(result).to include('1,251')          # max tick, delimited
      expect(result).not_to include('USD 1,251')  # unit dropped from the axis
    end

    it 'uses a fixed viewBox regardless of day count (constant rendered height)' do
      seven  = (1..7).to_h  { |d| [ Date.new(2026, 6, d), d ] }
      thirty = (1..30).to_h { |d| [ Date.new(2026, 6, d), d ] }
      r7  = helper.area_chart_svg(seven,  label: 'x')
      r30 = helper.area_chart_svg(thirty, label: 'x')

      viewbox = ->(svg) { svg[/viewBox="[^"]+"/] }
      expect(viewbox.call(r7)).to eq(viewbox.call(r30))
    end

    it 'renders one x-axis day label per data point (no thinning)' do
      series = (2..8).to_h { |d| [ Date.new(2026, 6, d), 1 ] } # old thinning would drop most of these
      result = helper.area_chart_svg(series, label: 'x')
      expect(result.scan('chart-axis-x').size).to eq(series.size)
    end

    it 'prints a value digit per non-zero day when show_values is on, skipping zeros' do
      result = helper.area_chart_svg(count_series, label: 'x', format: :count, show_values: true)
      expect(result.scan('class="chart-value"').size).to eq(3) # values 3, 1, 5; two zeros skipped
    end

    it 'labels money-chart points with their delimited amount when show_values is on' do
      money_series = { Date.new(2026, 6, 1) => 1000, Date.new(2026, 6, 2) => 300 }
      result = helper.area_chart_svg(money_series, label: 'x', format: :money, show_values: true)
      expect(result.scan('class="chart-value"').size).to eq(2)
      expect(result).to include('>300<') # a value label (300 is not a y-axis tick here)
    end

    it 'omits value digits by default' do
      result = helper.area_chart_svg(count_series, label: 'x', format: :count)
      expect(result).not_to include('class="chart-value"')
    end

    it 'renders a single-day series without error (point centered, no divide-by-zero)' do
      one = { Date.new(2026, 6, 1) => 4 }
      expect { helper.area_chart_svg(one, label: 'x', show_values: true) }.not_to raise_error
      expect(helper.area_chart_svg(one, label: 'x', show_values: true).scan('class="chart-value"').size).to eq(1)
    end

    it 'renders a valid svg for an empty series (no line path)' do
      result = helper.area_chart_svg({}, label: 'x')
      expect(result).to include('role="img"')
      expect(result).not_to include('class="chart-line"')
    end
  end
end
