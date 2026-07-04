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

    it 'formats money axis labels with USD' do
      money_series = { Date.new(2026, 6, 2) => 1250.5, Date.new(2026, 6, 3) => 0 }
      result = helper.area_chart_svg(money_series, label: 'x', format: :money)
      expect(result).to include('USD')
    end
  end
end
