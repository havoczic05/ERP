require 'rails_helper'

RSpec.describe DashboardHelper, type: :helper do
  describe '#bar_chart_svg' do
    let(:count_series) do
      {
        Date.new(2026, 6, 1) => 0,
        Date.new(2026, 6, 2) => 3,
        Date.new(2026, 6, 3) => 1,
        Date.new(2026, 6, 4) => 0,
        Date.new(2026, 6, 5) => 5
      }
    end

    it 'renders one bar rect per day in the series' do
      result = helper.bar_chart_svg(count_series, label: 'Ventas por día')
      expect(result.scan('class="bar"').size).to eq(count_series.size)
    end

    it 'renders axis text labels (days and value scale)' do
      result = helper.bar_chart_svg(count_series, label: 'Ventas por día')
      expect(result).to include('<text')
      expect(result).to include('chart-axis')
    end

    it 'is a responsive svg (no preserveAspectRatio="none" that would distort text)' do
      result = helper.bar_chart_svg(count_series, label: 'Ventas por día')
      expect(result).not_to include('preserveAspectRatio="none"')
    end

    it 'keeps the accessible role and aria-label' do
      result = helper.bar_chart_svg(count_series, label: 'Ventas por día del mes')
      expect(result).to include('role="img"')
      expect(result).to include('aria-label="Ventas por día del mes"')
    end

    it 'formats count tooltips in Spanish with singular/plural' do
      result = helper.bar_chart_svg(count_series, label: 'x', format: :count)
      expect(result).to include('<title>02/06 — 3 ventas</title>')
      expect(result).to include('<title>03/06 — 1 venta</title>')
    end

    it 'formats money tooltips and axis labels with USD' do
      money_series = { Date.new(2026, 6, 2) => 1250.5, Date.new(2026, 6, 3) => 0 }
      result = helper.bar_chart_svg(money_series, label: 'x', format: :money)
      expect(result).to include('USD')
      expect(result).to match(%r{<title>02/06 —.*USD.*1,250\.50</title>})
    end
  end
end
