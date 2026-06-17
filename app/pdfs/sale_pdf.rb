require "prawn"
require "prawn/table"

# Renders a commercial document (cotizacion or venta) as a PDF.
#
# RF5.4: injects the company logo, razon_social and RUC (from CompanySettings)
# into the header at render time. Pure Ruby (Prawn) — no headless browser, so it
# runs in CI without Chrome.
class SalePdf < Prawn::Document
  def initialize(sale, company_settings)
    super(page_size: "A4", margin: 40)
    @sale = sale
    @company = company_settings

    build_company_header
    build_document_title
    build_client_block
    build_items_table
    build_totals
    build_installments if @sale.installments.any?
    build_notes if @sale.notes.present?
  end

  private

  def build_company_header
    embed_logo
    text @company.razon_social.to_s, size: 16, style: :bold
    text "RUC: #{@company.ruc}"
    text @company.direccion if @company.direccion.present?
    text "Tel: #{@company.telefono}" if @company.telefono.present?
    move_down 12
  end

  def embed_logo
    return unless @company.logo.attached?

    image StringIO.new(@company.logo.download), width: 90, position: :left
    move_down 6
  rescue Prawn::Errors::UnsupportedImageType
    # Unsupported image format — render the document without the logo rather than failing.
  end

  def build_document_title
    label = @sale.document_type.humanize.upcase
    label += " (ANULADA)" if @sale.anulada?
    text "#{label} — #{@sale.correlative}", size: 14, style: :bold
    move_down 8
  end

  def build_client_block
    client = @sale.client
    text "Cliente: #{client.full_name}"
    text "Documento: #{client.document_type.upcase} #{client.document_number}"
    move_down 8
  end

  def build_items_table
    rows = [ %w[Producto Cant. P.Unit. Total] ]
    @sale.sale_items.each do |item|
      rows << [
        item.product.name,
        item.quantity.to_s,
        fmt(item.unit_price_usd),
        fmt(item.line_total_usd)
      ]
    end

    table(rows, header: true, width: bounds.width) do
      row(0).font_style = :bold
    end
    move_down 8
  end

  def build_totals
    text "Subtotal: #{fmt(@sale.subtotal_usd)}"
    text "Impuesto: #{fmt(@sale.tax_usd)}"
    text "Total: #{fmt(@sale.total_usd)}", style: :bold
    move_down 8
  end

  def build_installments
    text "Cuotas", style: :bold
    rows = [ %w[# Monto Saldo Vencimiento Estado] ]
    @sale.installments.order(:installment_number).each do |inst|
      rows << [
        inst.installment_number.to_s,
        fmt(inst.amount_usd),
        fmt(inst.balance_usd),
        inst.due_date.iso8601,
        inst.status.humanize
      ]
    end

    table(rows, header: true, width: bounds.width) do
      row(0).font_style = :bold
    end
    move_down 8
  end

  def build_notes
    text "Notas: #{@sale.notes}"
  end

  def fmt(value)
    ActiveSupport::NumberHelper.number_to_currency(value, unit: "USD ")
  end
end
