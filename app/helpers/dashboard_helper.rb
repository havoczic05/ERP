module DashboardHelper
  PLOT_HEIGHT = 120
  BAR_WIDTH = 14
  BAR_GAP = 4

  # Margins around the plot area that hold the axis labels.
  MARGIN_LEFT = 36   # y-axis value labels
  MARGIN_RIGHT = 6
  MARGIN_TOP = 10
  MARGIN_BOTTOM = 16 # x-axis day labels

  # Renders a KPI trend badge from a percent change vs. the previous month.
  # Returns nil (no badge) when `percent` is nil — i.e. there is no baseline to
  # compare against. Direction is conveyed by arrow + colour class; the value is
  # always shown as a magnitude (the sign lives in the arrow).
  def trend_badge(percent)
    return if percent.nil?

    if percent.positive?
      direction, symbol, word = "up", "▲", "subió"
    elsif percent.negative?
      direction, symbol, word = "down", "▼", "bajó"
    else
      direction, symbol, word = "flat", "→", "sin cambios"
    end

    magnitude = format("%.1f", percent.abs)
    tag.span("#{symbol} #{magnitude}%", class: "trend trend--#{direction}",
             title: "#{word} #{magnitude}% vs. el mes pasado")
  end

  # Renders a {Date => Numeric} series as an inline SVG area chart — an indigo
  # trend line over a gradient fill that fades to transparent at the baseline.
  # Server-rendered (no JS / no charting library) so it stays fully covered by
  # rack_test system specs — the CI/WSL2 environment has no headless browser.
  #
  # `label`  sets the accessible name for screen readers (aria-label).
  # `format` is :count (integer values) or :money (USD amounts); it drives how
  #          the y-axis labels and per-day tooltips are formatted.
  def area_chart_svg(data, label: nil, format: :count)
    max = data.values.map(&:to_f).max.to_f
    max = 1.0 if max <= 0
    slot = BAR_WIDTH + BAR_GAP
    plot_width = [ data.size * slot, 1 ].max

    total_width = MARGIN_LEFT + plot_width + MARGIN_RIGHT
    total_height = MARGIN_TOP + PLOT_HEIGHT + MARGIN_BOTTOM

    points = area_points(data, max, slot)
    gradient_id = area_gradient_id(label)

    elements = [ area_gradient_defs(gradient_id) ]
    elements.concat(chart_y_axis(max, plot_width, format))
    elements << area_fill_path(points, gradient_id)
    elements << area_line_path(points)
    elements.concat(area_hover_targets(data, slot, format))
    elements.concat(chart_x_axis(data, slot, total_height))

    tag.svg(safe_join(elements), width: total_width, height: total_height,
            viewBox: "0 0 #{total_width} #{total_height}",
            role: "img", "aria-label": label)
  end

  private

  # [x, y] coordinate per data point, aligned with the bar-chart x-axis labels.
  def area_points(data, max, slot)
    data.each_with_index.map do |(_date, value), index|
      x = MARGIN_LEFT + (index * slot) + (BAR_WIDTH / 2.0)
      y = MARGIN_TOP + (PLOT_HEIGHT - (value.to_f / max * PLOT_HEIGHT)).round(2)
      [ x.round(2), y ]
    end
  end

  # The trend line itself (stroke only, filled area is a separate element).
  def area_line_path(points)
    tag.path(nil, d: line_commands(points), fill: "none", class: "chart-line")
  end

  # The line closed down to the baseline and back, filled with the gradient.
  def area_fill_path(points, gradient_id)
    baseline = MARGIN_TOP + PLOT_HEIGHT
    d = "#{line_commands(points)} L #{points.last[0]} #{baseline} " \
        "L #{points.first[0]} #{baseline} Z"
    tag.path(nil, d: d, fill: "url(##{gradient_id})", class: "chart-area")
  end

  # Transparent hit areas over each point that surface a native hover tooltip,
  # preserving the per-day tooltip affordance the bar chart had.
  def area_hover_targets(data, slot, format)
    data.each_with_index.map do |(date, value), index|
      x = MARGIN_LEFT + (index * slot)
      tag.rect(x: x, y: MARGIN_TOP, width: slot, height: PLOT_HEIGHT,
               fill: "transparent", class: "chart-hit") do
        tag.title("#{date.strftime('%d/%m')} — #{format_tooltip_value(value, format)}")
      end
    end
  end

  def line_commands(points)
    "M #{points.first[0]} #{points.first[1]} " +
      points[1..].map { |x, y| "L #{x} #{y}" }.join(" ")
  end

  # A vertical indigo gradient fading to transparent at the baseline.
  def area_gradient_defs(gradient_id)
    tag.defs(
      tag.linearGradient(x1: "0", y1: "0", x2: "0", y2: "1", id: gradient_id) do
        safe_join([
          tag.stop(offset: "0%",   class: "chart-area-stop-top"),
          tag.stop(offset: "100%", class: "chart-area-stop-bottom")
        ])
      end
    )
  end

  # Unique per chart so multiple area charts on one page don't share a fill.
  def area_gradient_id(label)
    slug = label.to_s.parameterize.presence || "chart"
    "area-grad-#{slug}"
  end

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

  # Day-of-month labels, thinned out to avoid crowding ~30 points.
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
