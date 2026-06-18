module ApplicationHelper
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

  # Returns an html_safe <span> with the appropriate badge class for a sale's status.
  def sale_status_badge(sale)
    variant = SALE_BADGE_VARIANT.fetch(sale.status, "info")
    content_tag(:span, sale.status.humanize, class: "badge badge--#{variant}")
  end

  # Returns an html_safe <span> with the appropriate badge class for an installment's status.
  def installment_status_badge(installment)
    variant = INSTALLMENT_BADGE_VARIANT.fetch(installment.status, "info")
    content_tag(:span, installment.status.humanize, class: "badge badge--#{variant}")
  end
end
