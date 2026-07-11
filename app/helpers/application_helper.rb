module ApplicationHelper
  # ---------------------------------------------------------------------------
  # Document type display labels (enum values stay English/lowercase)
  # ---------------------------------------------------------------------------
  DOCUMENT_TYPE_LABELS = {
    "cotizacion" => "Cotización",
    "venta"      => "Venta"
  }.freeze

  def document_type_label(type)
    DOCUMENT_TYPE_LABELS.fetch(type.to_s, type.to_s.humanize)
  end

  # Formats a date/time as dd/mm/aaaa in the app's local time zone (America/Lima).
  # Returns "" for nil. No i18n — Spanish-hardcoded project convention.
  def format_date(value)
    value&.strftime("%d/%m/%Y").to_s
  end

  # ---------------------------------------------------------------------------
  # Status badge variant maps
  # ---------------------------------------------------------------------------
  SALE_BADGE_VARIANT = {
    "confirmada" => "success",
    "anulada"    => "danger"
  }.freeze

  INSTALLMENT_BADGE_VARIANT = {
    "pendiente" => "warning",
    "pagada"    => "success",
    "vencida"   => "danger",
    "anulada"   => "danger"
  }.freeze

  INSTALLMENT_BADGE_LABEL = {
    "pendiente" => "Pendiente",
    "pagada"    => "Pagada",
    "vencida"   => "Vencida",
    "anulada"   => "Anulada"
  }.freeze

  # Returns an html_safe <span> with the appropriate badge class for a sale's status.
  def sale_status_badge(sale)
    variant = SALE_BADGE_VARIANT.fetch(sale.status, "info")
    content_tag(:span, sale.status.humanize, class: "badge badge--#{variant}")
  end

  # Decorates a sale's installments (ordered) with the two values the detail view
  # shows but the model does not store:
  #   :saldo_restante — running outstanding balance BEFORE this installment, i.e.
  #     the sale total minus the amounts of all prior installments (a schedule
  #     view: "how much was still owed on arriving at this cuota").
  #   :paid_on        — the latest amortization paid_at for this installment, or nil.
  def sale_installment_rows(sale)
    total   = sale.total_usd
    running = BigDecimal("0")

    sale.installments.includes(:amortizations).order(:installment_number).map do |installment|
      saldo    = total - running
      running += installment.amount_usd
      { installment: installment,
        saldo_restante: saldo,
        paid_on: installment.amortizations.map(&:paid_at).max }
    end
  end

  # Returns an html_safe <span> with the appropriate badge class for an installment's status.
  # Labels are rendered in Spanish; badge variant is driven by the DB enum value.
  def installment_status_badge(installment)
    status  = installment.overdue? ? "vencida" : installment.status
    variant = INSTALLMENT_BADGE_VARIANT.fetch(status, "info")
    label   = INSTALLMENT_BADGE_LABEL.fetch(status, status.humanize)
    content_tag(:span, label, class: "badge badge--#{variant}")
  end

  # Renders a sidebar navigation link. Marks itself active (background tint +
  # aria-current) when the current request is handled by one of `controllers`,
  # so a section stays highlighted across its nested pages (e.g. /sales/123).
  # An optional `icon:` renders a leading SVG (the label stays as text so link
  # matchers keep working).
  def nav_link_to(label, path, controllers:, icon: nil)
    active = Array(controllers).include?(controller_name)
    link_to path,
            class: class_names("nav-item", "is-active" => active),
            aria: { current: active ? "page" : nil } do
      action_content(label, icon)
    end
  end

  # ---------------------------------------------------------------------------
  # Action controls — single source of truth for the visual hierarchy of
  # buttons/links across index ".row-actions" cells and ".action-bar" footers.
  #
  #   primary  -> filled brand button (one CTA per screen)
  #   ghost    -> neutral outline (routine: Ver / Editar / Volver / PDF)
  #   danger   -> red outline (destructive: Eliminar / Anular / Archivar)
  #
  # Both helpers keep the exact visible Spanish label so system specs that match
  # on have_link / have_button / click_button stay green.
  # ---------------------------------------------------------------------------

  # Renders a styled <a> for a navigation/routine action.
  def action_link(label, path, variant: :ghost, size: :sm, icon: nil, **opts)
    link_to path, **opts.merge(class: btn_classes(variant, size, opts[:class])) do
      action_content(label, icon)
    end
  end

  # Renders a styled button_to (a small inline <form><button>) for a state-changing
  # action. `confirm:` becomes a Turbo confirmation dialog.
  def action_button(label, path, variant: :danger, size: :sm, icon: nil,
                     method: :post, confirm: nil, **opts)
    data = (opts.delete(:data) || {})
    data = data.merge(turbo_confirm: confirm) if confirm
    button_to path, **opts.merge(
      method: method,
      data: data,
      form: { class: "button_to" },
      class: btn_classes(variant, size, opts[:class])
    ) do
      action_content(label, icon)
    end
  end

  # Renders a styled submit button for a form (single source of truth for the
  # primary CTA inside <%= form_with %> blocks). `f` is the form builder.
  # Keeps the exact visible Spanish label so system specs that match on
  # click_button / have_button stay green.
  def submit_button(f, label, variant: :primary, size: :md, **opts)
    f.submit label, **opts.merge(class: btn_classes(variant, size, opts[:class]))
  end

  # ---------------------------------------------------------------------------
  # Inline SVG icons — curated Lucide-style set (stroke 1.5). No gem, no Node.
  # Returns an html_safe <svg>, or nil for an unknown name.
  # ---------------------------------------------------------------------------
  ICON_PATHS = {
    eye:        '<path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>',
    pencil:     '<path d="M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z"/><path d="m15 5 4 4"/>',
    trash:      '<path d="M3 6h18"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><line x1="10" x2="10" y1="11" y2="17"/><line x1="14" x2="14" y1="11" y2="17"/>',
    ban:        '<circle cx="12" cy="12" r="10"/><path d="m4.9 4.9 14.2 14.2"/>',
    archive:    '<rect width="20" height="5" x="2" y="3" rx="1"/><path d="M4 8v11a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8"/><path d="M10 12h4"/>',
    "user-x":   '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><line x1="17" x2="22" y1="8" y2="13"/><line x1="22" x2="17" y1="8" y2="13"/>',
    download:   '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" x2="12" y1="15" y2="3"/>',
    plus:       '<path d="M5 12h14"/><path d="M12 5v14"/>',
    "arrow-left": '<path d="m12 19-7-7 7-7"/><path d="M19 12H5"/>',
    x:          '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
    refresh:    '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M8 16H3v5"/>',
    user:       '<circle cx="12" cy="12" r="10"/><circle cx="12" cy="10" r="3"/><path d="M7 20.662V19a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v1.662"/>',
    info:       '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>',
    receipt:    '<path d="M4 2v20l2-1 2 1 2-1 2 1 2-1 2 1 2-1 2 1V2l-2 1-2-1-2 1-2-1-2 1-2-1-2 1-2-1Z"/><path d="M16 8h-6a2 2 0 1 0 0 4h4a2 2 0 1 1 0 4H8"/><path d="M12 17.5v-11"/>',
    users:      '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
    package:    '<path d="m7.5 4.27 9 5.15"/><path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/><path d="m3.3 7 8.7 5 8.7-5"/><path d="M12 22V12"/>',
    wallet:     '<path d="M19 7V4a1 1 0 0 0-1-1H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-3a2 2 0 0 0 0 4h3a1 1 0 0 0 1-1v-2a1 1 0 0 0-1-1"/><path d="M3 5v14a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-4"/>',
    "layout-grid": '<rect width="7" height="7" x="3" y="3" rx="1"/><rect width="7" height="7" x="14" y="3" rx="1"/><rect width="7" height="7" x="14" y="14" rx="1"/><rect width="7" height="7" x="3" y="14" rx="1"/>',
    settings:   '<path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2Z"/><circle cx="12" cy="12" r="3"/>'
  }.freeze

  def icon(name)
    body = ICON_PATHS[name.to_sym]
    return nil unless body

    content_tag(:svg, body.html_safe,
                class: "icon", viewBox: "0 0 24 24", width: 16, height: 16,
                fill: "none", stroke: "currentColor", "stroke-width": 1.5,
                "stroke-linecap": "round", "stroke-linejoin": "round",
                "aria-hidden": "true", focusable: "false")
  end

  # Renders a reusable searchable combobox (see app/views/shared/_combobox + the
  # combobox Stimulus controller). `hidden_name` carries the selected id on submit;
  # `query_name` is the visible display/text input. `select_action` wires the
  # `combobox:select` event to an embedding controller (e.g. "combobox:select->sale-form#x").
  # An optional block renders a suffix next to the input (e.g. selected-item meta).
  def combobox(query_name:, hidden_name:, search_path:, label: nil,
               hidden_value: nil, query_value: nil, placeholder: nil,
               select_action: nil, wrapper_class: nil, &suffix)
    render "shared/combobox",
           label: label, query_name: query_name, hidden_name: hidden_name,
           search_path: search_path, hidden_value: hidden_value, query_value: query_value,
           placeholder: placeholder, select_action: select_action,
           wrapper_class: wrapper_class,
           suffix: (capture(&suffix) if suffix)
  end

  # Renders a USD amount with a small, muted "USD" prefix so the number stays the
  # focal point (e.g. summary totals): <span class="amount-cur">USD</span> 1,173.68
  def usd_amount(value)
    safe_join([
      content_tag(:span, "USD", class: "amount-cur"),
      " ",
      number_with_precision(value, precision: 2, delimiter: ",")
    ])
  end

  # Money cell: the amount right-aligned with tabular figures (2 decimals).
  # The currency lives once in the column header (e.g. "Total (USD)"), so the
  # cells stay currency-free to avoid repeating "USD" on every row.
  def money(amount)
    tag.div(number_with_precision(amount, precision: 2, delimiter: ","), class: "money")
  end

  # Uniform search input for index toolbars. Renders the standard `.field`
  # wrapper with a "Buscar" label and the `q` text field so every table's search
  # box looks and behaves identically; the placeholder describes what each table
  # matches on. Keeps id/name "q" so existing GET filter forms keep working.
  def search_field(placeholder:, label: "Buscar")
    tag.div(class: "field") do
      safe_join([
        label_tag(:q, label),
        text_field_tag(:q, params[:q], placeholder: placeholder)
      ])
    end
  end

  # Clears every active filter on an index toolbar. Because the filter forms are
  # GET forms targeting their own index, "limpiar" is simply a link to the bare
  # path with no query string. Reused across sales/clients/products/AR.
  def clear_filters_link(path)
    action_link "Limpiar", path, variant: :ghost, size: :md, icon: :x
  end

  # Clickable table header that toggles ascending/descending date order while
  # preserving the active filters (and resetting the page). Default order is
  # descending (newest first). Reusable on any date-sortable index.
  def sortable_date_header(label)
    current  = params[:dir] == "asc" ? "asc" : "desc"
    next_dir = current == "asc" ? "desc" : "asc"
    arrow    = current == "asc" ? "▲" : "▼"
    query    = request.query_parameters.merge("dir" => next_dir).except("page")
    link_to safe_join([ label, " ", arrow ]), "#{request.path}?#{query.to_query}", class: "sortable"
  end

  # Reusable export button — opens the export (e.g. a CSV) in a new tab. Same
  # ghost style as the other actions; pass a path with the desired format/filters.
  def export_link(label, path)
    action_link(label, path, variant: :ghost, size: :md, icon: :download,
                target: "_blank", rel: "noopener")
  end

  # Reusable, accessible pagination (see app/views/shared/_pagination). Renders a
  # numbered nav with Anterior/Siguiente + a "Mostrando X–Y de N" count. Works
  # with any Pagy offset object and preserves the current query string (filters).
  def pagination_nav(pagy)
    render "shared/pagination", pagy: pagy
  end

  # URL for a given page, preserving the current path + query params (filters).
  def pagination_page_url(page)
    "#{request.path}?#{request.query_parameters.merge('page' => page).to_query}"
  end

  # Page series with gaps, e.g. [1, :gap, 4, 5, 6, :gap, 12]. Window = pages on
  # each side of the current page.
  def pagination_series(current, total, window: 1)
    return (1..total).to_a if total <= 7

    series = [ 1 ]
    series << :gap if current - window > 2
    ((current - window)..(current + window)).each { |p| series << p if p > 1 && p < total }
    series << :gap if current + window < total - 1
    series << total
    series
  end

  private

  # Builds the button class string. :primary uses the bare .btn (filled brand);
  # :ghost / :danger add their modifier; :sm adds the compact size.
  def btn_classes(variant, size, extra = nil)
    class_names(
      "btn",
      "btn--ghost"  => variant == :ghost,
      "btn--danger" => variant == :danger,
      "btn--sm"     => size == :sm,
      extra.to_s    => extra.present?
    )
  end

  # Icon + label, so the visible text is always present for accessibility and specs.
  def action_content(label, icon_name)
    safe_join([ icon_name ? icon(icon_name) : nil, content_tag(:span, label) ].compact)
  end
end
