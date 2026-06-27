module DashboardHelper
  PLOT_HEIGHT = 120
  BAR_WIDTH = 14
  BAR_GAP = 4

  # Margins around the plot area that hold the axis labels.
  MARGIN_LEFT = 36   # y-axis value labels
  MARGIN_RIGHT = 6
  MARGIN_TOP = 10
  MARGIN_BOTTOM = 16 # x-axis day labels

  # Renders a {Date => Numeric} series as an inline SVG bar chart with labelled
  # axes and readable hover tooltips. Server-rendered (no JS) so it stays fully
  # covered by rack_test system specs — the CI/WSL2 environment has no headless
  # browser for JS charting libraries.
  #
  # `label`  sets the accessible name for screen readers (aria-label).
  # `format` is :count (integer values) or :money (USD amounts); it drives how
  #          the y-axis labels and per-bar tooltips are formatted.
  def bar_chart_svg(data, label: nil, format: :count)
    max = data.values.map(&:to_f).max.to_f
    max = 1.0 if max <= 0
    slot = BAR_WIDTH + BAR_GAP
    plot_width = [ data.size * slot, 1 ].max

    total_width = MARGIN_LEFT + plot_width + MARGIN_RIGHT
    total_height = MARGIN_TOP + PLOT_HEIGHT + MARGIN_BOTTOM

    elements = chart_y_axis(max, plot_width, format)
    elements.concat(chart_bars(data, max, slot, format))
    elements.concat(chart_x_axis(data, slot, total_height))

    tag.svg(safe_join(elements), width: total_width, height: total_height,
            viewBox: "0 0 #{total_width} #{total_height}",
            role: "img", "aria-label": label)
  end

  private

  # Horizontal gridlines + value labels at 0, half, and max.
  def chart_y_axis(max, plot_width, format)
    [ 0.0, max / 2.0, max ].map do |tick|
      y = MARGIN_TOP + (PLOT_HEIGHT - (tick / max * PLOT_HEIGHT)).round(2)
      safe_join([
        tag.line(x1: MARGIN_LEFT, y1: y, x2: MARGIN_LEFT + plot_width, y2: y, class: "chart-grid"),
        tag.text(format_axis_value(tick, format), x: MARGIN_LEFT - 4, y: y + 3,
                 "text-anchor": "end", class: "chart-axis")
      ])
    end
  end

  def chart_bars(data, max, slot, format)
    data.each_with_index.map do |(date, value), index|
      height = (value.to_f / max * PLOT_HEIGHT).round(2)
      x = MARGIN_LEFT + (index * slot)
      tag.rect(x: x, y: MARGIN_TOP + (PLOT_HEIGHT - height),
               width: BAR_WIDTH, height: height, class: "bar",
               data: { day: date.day, value: value }) do
        tag.title("#{date.strftime('%d/%m')} — #{format_tooltip_value(value, format)}")
      end
    end
  end

  # Day-of-month labels, thinned out to avoid crowding ~30 bars.
  def chart_x_axis(data, slot, total_height)
    last_index = data.size - 1
    data.each_with_index.filter_map do |(date, _value), index|
      next unless date.day == 1 || (date.day % 5).zero? || index == last_index

      x = MARGIN_LEFT + (index * slot) + (BAR_WIDTH / 2.0)
      tag.text(date.day, x: x, y: total_height - 4, "text-anchor": "middle", class: "chart-axis")
    end
  end

  def format_axis_value(value, format)
    if format == :money
      number_to_currency(value, unit: "USD ", precision: 0)
    else
      value.round.to_s
    end
  end

  def format_tooltip_value(value, format)
    if format == :money
      number_to_currency(value, unit: "USD ")
    else
      count = value.to_i
      "#{count} #{count == 1 ? 'venta' : 'ventas'}"
    end
  end
end
