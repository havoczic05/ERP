module DashboardHelper
  CHART_HEIGHT = 120
  BAR_WIDTH = 14
  BAR_GAP = 4

  # Renders a {Date => Numeric} series as an inline SVG bar chart.
  # Server-rendered (no JS) so it is fully covered by rack_test system specs —
  # the CI/WSL2 environment has no headless browser for JS charting libraries.
  def bar_chart_svg(data)
    max = data.values.map(&:to_f).max.to_f
    max = 1.0 if max <= 0
    slot = BAR_WIDTH + BAR_GAP
    width = [ data.size * slot, 1 ].max

    bars = data.each_with_index.map do |(date, value), index|
      height = (value.to_f / max * CHART_HEIGHT).round(2)
      tag.rect(x: index * slot, y: CHART_HEIGHT - height,
               width: BAR_WIDTH, height: height, class: "bar",
               data: { day: date.day, value: value }) do
        tag.title("#{date.iso8601}: #{value}")
      end
    end

    tag.svg(safe_join(bars), width: width, height: CHART_HEIGHT, role: "img")
  end
end
