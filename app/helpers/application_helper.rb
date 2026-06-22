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
end
