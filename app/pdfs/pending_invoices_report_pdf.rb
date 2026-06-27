# Renders the accounts-receivable "facturas pendientes / vencidas" report as a
# PDF, grouped per client. Reuses the company's branded header and bank footer
# (see BrandedPdf). Receives the already-filtered current-installment rows (one
# per sale) and a { sale_id => outstanding balance } hash from the controller, so
# it stays free of query logic.
class PendingInvoicesReportPdf < BrandedPdf
  def initialize(installments, balances, company_settings)
    super()
    @installments = installments
    @balances = balances
    @company = company_settings

    build_doc_meta(label: "FACTURAS PENDIENTES", date: Date.current.strftime("%d/%m/%Y"))
    build_branded_header(@company)
    build_report_title
    build_client_sections
    build_bank_footer(@company)
  end

  private

  def build_report_title
    fill_color BRAND
    text "Reporte de facturas pendientes / vencidas", size: 13, style: :bold
    fill_color INK
    move_down 10
  end

  def build_client_sections
    # Flow client sections one after another (Prawn paginates as needed) instead
    # of forcing a page break per client, so a multi-client report stays compact.
    @installments.group_by { |inst| inst.sale.client }.each do |client, rows|
      build_client_section(client, rows)
    end
  end

  def build_client_section(client, installments)
    move_down 6
    text "CLIENTE: #{client.full_name}", size: 10, style: :bold
    text "R.U.C.: #{client.document_number}", size: 10
    move_down 6

    rows = [ [ "N°", "ESTADO", "FECHA DE EMISIÓN", "FACTURA", "TOTAL" ] ]
    installments.each_with_index do |inst, i|
      rows << [
        (i + 1).to_s,
        inst.overdue? ? "Vencida" : "Pendiente",
        inst.sale.created_at.strftime("%d/%m/%Y"),
        inst.sale.correlative,
        fmt(@balances[inst.sale_id])
      ]
    end

    branded_table(rows, column_widths: { 0 => 32 }) do |t|
      t.column(0).align = :center
      t.column(4).align = :right
    end

    build_client_total(installments)
  end

  def build_client_total(installments)
    total = installments.sum { |inst| @balances[inst.sale_id].to_f }
    move_down 4

    table([ [ "TOTAL PENDIENTE", fmt(total) ] ], position: :right, width: 240) do |t|
      t.cells.background_color = BRAND_WEAK
      t.cells.borders = []
      t.cells.padding = [ 6, 8 ]
      t.cells.font_style = :bold
      t.column(1).align = :right
    end
    move_down 10
  end
end
