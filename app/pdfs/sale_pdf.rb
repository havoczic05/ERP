# Renders a commercial document (cotizacion or venta) as a PDF, following the
# company's branded layout (see BrandedPdf): branded header + document meta,
# client block, line-items table, totals, optional installments, and the
# bank-accounts footer. Injects company logo/razon_social/RUC from CompanySettings.
class SalePdf < BrandedPdf
  def initialize(sale, company_settings)
    super()
    @sale = sale
    @company = company_settings

    build_doc_meta(label: document_label, reference: @sale.correlative,
                   date: @sale.created_at.strftime("%d/%m/%Y"))
    build_branded_header(@company)
    build_client_block
    build_items_table
    build_totals
    build_installments if @sale.installments.any?
    build_bank_footer(@company)
  end

  private

  def document_label
    label = @sale.document_type.humanize.upcase
    label += " (ANULADA)" if @sale.anulada?
    label
  end

  def build_client_block
    client = @sale.client
    text "CLIENTE: #{client.full_name}", size: 10
    text "R.U.C.: #{client.document_number}", size: 10
    text "DIRECCIÓN: #{client.direccion}", size: 10 if client.direccion.present?
    text "OBSERVACIÓN: #{@sale.notes}", size: 10 if @sale.notes.present?
    move_down 10
  end

  def build_items_table
    rows = [ [ "ITEM", "CANTIDAD", "CÓDIGO", "DESCRIPCIÓN", "PRECIO UNITARIO (INC. IGV)", "TOTAL" ] ]
    @sale.sale_items.each_with_index do |item, index|
      rows << [
        (index + 1).to_s,
        item.quantity.to_s,
        item.product.sku,
        item.product.name,
        fmt(item.unit_price_usd),
        fmt(item.line_total_usd)
      ]
    end

    branded_table(rows, column_widths: { 0 => 42, 1 => 58, 2 => 78, 4 => 118, 5 => 72 }) do |t|
      t.column(0).align = :center
      t.column(1).align = :center
      t.column(4).align = :right
      t.column(5).align = :right
    end
    move_down 8
  end

  def build_totals
    text "Subtotal: #{fmt(@sale.subtotal_usd)}", size: 10, align: :right
    text "Impuesto: #{fmt(@sale.tax_usd)}", size: 10, align: :right
    move_down 4

    table([ [ "TOTAL", fmt(@sale.total_usd) ] ], position: :right, width: 220) do |t|
      t.cells.background_color = BRAND_WEAK
      t.cells.borders = []
      t.cells.padding = [ 6, 8 ]
      t.cells.font_style = :bold
      t.column(1).align = :right
    end
    move_down 8
  end

  def build_installments
    move_down 8
    text "Cuotas", style: :bold, size: 11
    move_down 4

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

    branded_table(rows) do |t|
      t.column(1).align = :right
      t.column(2).align = :right
    end
    move_down 8
  end
end
