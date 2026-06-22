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
  def nav_link_to(label, path, controllers:)
    active = Array(controllers).include?(controller_name)
    link_to label, path,
            class: class_names("nav-item", "is-active" => active),
            aria: { current: active ? "page" : nil }
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
    "arrow-left": '<path d="m12 19-7-7 7-7"/><path d="M19 12H5"/>'
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
