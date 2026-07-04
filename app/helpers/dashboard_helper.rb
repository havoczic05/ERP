module DashboardHelper
  PLOT_HEIGHT = 84
  # Fixed plot width — the chart always uses the same viewBox aspect ratio, so
  # its rendered height stays constant across ranges (7/30/31 days) under the
  # CSS `width:100%; height:auto`. Days are distributed proportionally within it.
  PLOT_WIDTH = 558

  # Human labels for each chart time-range, keyed by the value the service
  # accepts (DashboardMetrics::VALID_CHART_RANGES is the single source of truth
  # for which ranges exist and in what order).
  CHART_RANGE_LABELS = { "month" => "Mes", "30d" => "30 días", "7d" => "7 días" }.freeze

  # Margins around the plot area that hold the axis labels.
  MARGIN_LEFT = 36   # y-axis value labels
  MARGIN_RIGHT = 6
  MARGIN_TOP = 10
  MARGIN_BOTTOM = 16 # x-axis day labels

  # Renders a USD amount for a KPI tile with the "USD" unit in a smaller, lighter
  # span so it doesn't compete with the number for attention. Returns html-safe
  # markup: <span class="kpi-unit">USD</span> 1,234.50
  def kpi_currency(amount)
    safe_join([ tag.span("USD", class: "kpi-unit"), number_to_currency(amount, unit: "") ], " ")
  end

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

  # Segmented control that switches the temporal charts' time window. Each
  # option is a GET link back to the dashboard carrying ?range=; the active one
  # is marked with aria-current for assistive tech and a modifier class for CSS.
  def chart_range_toggle(active)
    active = active.to_s
    options = DashboardMetrics::VALID_CHART_RANGES.map do |value|
      current = value == active
      link_to(CHART_RANGE_LABELS[value], dashboard_path(range: value),
              class: "range-opt#{' range-opt--active' if current}",
              aria: { current: current ? "true" : nil })
    end
    tag.div(safe_join(options), class: "chart-range", role: "group",
            "aria-label": "Rango de tiempo de los gráficos")
  end

  # Renders a {Date => Numeric} series as an inline SVG area chart — an indigo
  # trend line over a gradient fill that fades to transparent at the baseline.
  # Server-rendered (no JS / no charting library) so it stays fully covered by
  # rack_test system specs — the CI/WSL2 environment has no headless browser.
  #
  # `label`       sets the accessible name for screen readers (aria-label).
  # `format`      is :count (integer values) or :money (USD amounts); it drives
  #               how the y-axis labels and per-day tooltips are formatted.
  # `show_values` prints each non-zero day's value as a digit on the line (used
  #               by the count chart; the money chart keeps the y-axis only).
  def area_chart_svg(data, label: nil, format: :count, show_values: false)
    max = data.values.map(&:to_f).max.to_f
    max = 1.0 if max <= 0

    total_width = MARGIN_LEFT + PLOT_WIDTH + MARGIN_RIGHT
    total_height = MARGIN_TOP + PLOT_HEIGHT + MARGIN_BOTTOM

    points = area_points(data, max)
    gradient_id = area_gradient_id(label)

    elements = [ area_gradient_defs(gradient_id) ]
    elements.concat(chart_y_axis(max, PLOT_WIDTH, format))
    if points.any?
      elements << area_fill_path(points, gradient_id)
      elements << area_line_path(points)
      elements.concat(area_hover_targets(data, format))
      elements.concat(area_value_labels(data, points, format)) if show_values
      elements.concat(chart_x_axis(data, total_height))
    end

    tag.svg(safe_join(elements), width: total_width, height: total_height,
            viewBox: "0 0 #{total_width} #{total_height}",
            role: "img", "aria-label": label)
  end

  private

  # Width of a single day's band within the fixed plot width.
  def band_step(count) = PLOT_WIDTH / count.to_f

  # Band-CENTER x for the data point at `index`. Centering sidesteps the N==1
  # divide-by-zero (the lone point lands at the plot center).
  def point_x(index, count) = MARGIN_LEFT + ((index + 0.5) * band_step(count))

  # [x, y] coordinate per data point, spaced proportionally across the fixed plot.
  def area_points(data, max)
    n = data.size
    data.each_with_index.map do |(_date, value), index|
      x = point_x(index, n).round(2)
      y = MARGIN_TOP + (PLOT_HEIGHT - (value.to_f / max * PLOT_HEIGHT)).round(2)
      [ x, y ]
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

  # Transparent hit areas over each day's band that surface a native hover
  # tooltip, preserving the per-day tooltip affordance the bar chart had.
  def area_hover_targets(data, format)
    n = data.size
    step = band_step(n)
    data.each_with_index.map do |(date, value), index|
      x = MARGIN_LEFT + (index * step)
      tag.rect(x: x.round(2), y: MARGIN_TOP, width: step.round(2), height: PLOT_HEIGHT,
               fill: "transparent", class: "chart-hit") do
        tag.title("#{date.strftime('%d/%m')} — #{format_tooltip_value(value, format)}")
      end
    end
  end

  # One visible digit per non-zero day, printed just above its point. Zero days
  # are skipped so the chart doesn't fill with "0"s.
  def area_value_labels(data, points, format)
    data.each_with_index.filter_map do |(_date, value), index|
      next if value.to_f.zero?

      x, y = points[index]
      label_y = [ y - 4, MARGIN_TOP + 6 ].max # keep the peak label from clipping
      tag.text(format_value_label(value, format), x: x, y: label_y,
               "text-anchor": "middle", class: "chart-value")
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

  # Day-of-month labels — one per day (no thinning). The extra `chart-axis-x`
  # class both shrinks the font (so ~31 two-digit numbers fit) and is the marker
  # specs count; `chart-axis` keeps the shared axis styling.
  def chart_x_axis(data, total_height)
    n = data.size
    data.each_with_index.map do |(date, _value), index|
      x = point_x(index, n).round(2)
      tag.text(date.day, x: x, y: total_height - 4,
               "text-anchor": "middle", class: "chart-axis chart-axis-x")
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

  # Compact per-point label printed on the line. The unit already lives on the
  # y-axis, so this stays a bare number (integer count, or rounded amount).
  def format_value_label(value, format)
    format == :money ? number_with_delimiter(value.round) : value.to_i.to_s
  end
end
