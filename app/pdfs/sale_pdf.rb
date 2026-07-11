# Renders a commercial document (cotizacion or venta) as a PDF, following the
# company's branded layout (see BrandedPdf): faded company-name watermark,
# branded header + document meta, client block, line-items table, totals,
# optional installments, and the bank-accounts footer. Injects company
# logo/razon_social/RUC from CompanySettings.
class SalePdf < BrandedPdf
  # `show_installments:` toggles the cuotas section. The controller drives it from
  # the request (default PDF omits cuotas; a second "con cuotas" PDF is offered on
  # the sale page); the default here stays true for direct callers/specs.
  def initialize(sale, company_settings, show_installments: true)
    super()
    @sale = sale
    @company = company_settings

    build_watermark
    build_doc_meta(label: document_label, reference: @sale.correlative,
                   date: @sale.created_at.strftime("%d/%m/%Y"))
    build_branded_header(@company)
    build_client_block
    build_items_table
    build_totals
    build_installments if show_installments && @sale.installments.any?
    build_bank_footer(@company)
  end

  private

  # Large, faded, diagonal company name behind the content. Drawn first so every
  # later section paints over it; `text_box` never moves the cursor.
  def build_watermark
    name = @company.razon_social.to_s
    return if name.blank?

    cx = bounds.width / 2.0
    cy = bounds.height / 2.0
    fill_color MUTED
    transparent(0.06) do
      rotate(45, origin: [ cx, cy ]) do
        text_box name, at: [ cx - 300, cy + 30 ], width: 600, height: 60,
                 size: 46, style: :bold, align: :center, valign: :center,
                 overflow: :shrink_to_fit
      end
    end
    fill_color INK
  end

  def document_label
    label = @sale.document_type.humanize.upcase
    label += " (ANULADA)" if @sale.anulada?
    label
  end

  # CLIENTE / R.U.C. / DIRECCIÓN as an aligned label→value grid (borderless).
  def build_client_block
    client = @sale.client
    rows = [
      [ "CLIENTE", client.full_name.to_s ],
      [ "R.U.C.", client.document_number.to_s ]
    ]
    rows << [ "DIRECCIÓN", client.direccion ] if client.direccion.present?

    data = rows.map do |label, value|
      [
        { content: label, text_color: MUTED, font_style: :bold, size: 9 },
        { content: value, text_color: INK, size: 9 }
      ]
    end

    table(data, column_widths: { 0 => 92 }, width: bounds.width) do |t|
      t.cells.borders = []
      t.cells.padding = [ 1, 4, 1, 0 ]
    end
    move_down 12
  end

  def build_items_table
    rows = [ [ "ITEM", "CANTIDAD", "CÓDIGO", "DESCRIPCIÓN", "PRECIO UNITARIO (INC. IGV)", "TOTAL" ] ]
    @sale.sale_items.each_with_index do |item, index|
      rows << [
        (index + 1).to_s,
        item.quantity.to_s,
        item.product.sku,
        item.product.name,
        money_cell(item.unit_price_usd),
        money_cell(item.line_total_usd)
      ]
    end

    branded_table(rows, column_widths: { 0 => 40, 1 => 56, 2 => 76, 4 => 116, 5 => 74 }) do |t|
      t.column(0).align = :center
      t.column(1).align = :center
      t.column(4).align = :right
      t.column(5).align = :right
    end
    move_down 10
  end

  def build_totals
    fill_color MUTED
    text "Subtotal:  <font size='6'>USD</font> #{fmt_amount(@sale.subtotal_usd)}",
         size: 9, align: :right, inline_format: true
    fill_color INK
    move_down 8

    total = [ [ "TOTAL", "<font size='8'>USD</font> #{fmt_amount(@sale.total_usd)}" ] ]
    table(total, position: :right, width: 240) do |t|
      t.cells.background_color = WARNING_WEAK
      t.cells.borders = []
      t.cells.padding = [ 8, 12 ]
      t.cells.text_color = INK
      t.cells.font_style = :bold
      t.cells.inline_format = true
      t.column(0).size = 11
      t.column(1).size = 12
      t.column(1).align = :right
    end
    move_down 8
  end

  def build_installments
    move_down 8
    fill_color BRAND
    text "Cuotas", style: :bold, size: 11
    fill_color INK
    move_down 4

    rows = [ %w[# Monto Saldo Vencimiento Estado] ]
    @sale.installments.order(:installment_number).each do |inst|
      rows << [
        inst.installment_number.to_s,
        fmt(inst.amount_usd),
        fmt(inst.balance_usd),
        inst.due_date.strftime("%d/%m/%Y"),
        inst.status.humanize
      ]
    end

    branded_table(rows) do |t|
      t.column(1).align = :right
      t.column(2).align = :right
    end
    move_down 8
  end

  # A right-aligned amount cell where the "USD" prefix renders smaller than the
  # number, so the value reads as the focal point.
  def money_cell(value)
    { content: "<font size='6'>USD</font> #{fmt_amount(value)}", inline_format: true }
  end
end
