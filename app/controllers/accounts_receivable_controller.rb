class AccountsReceivableController < ApplicationController
  include CsvExport

  CSV_HEADERS = [ "Cliente", "Venta", "N° de cuota", "Monto Cuota (USD)",
                  "Saldo (USD)", "Vencimiento", "Estado" ].freeze

  # GET /accounts_receivable
  def index
    authorize Amortization, :index?
    # One row per sale: the current installment to collect = the earliest pending
    # installment per sale (DISTINCT ON picks the min due_date), covering both
    # "about to expire" and "already overdue".
    current_ids = Installment.where(status: "pendiente")
                             .select("DISTINCT ON (sale_id) id")
                             .order("sale_id, due_date ASC, installment_number ASC")
    scope = filter_installments(
      Installment.where(id: current_ids).includes(sale: :client).order(:due_date)
    )
    @subtotal = scope.sum(:balance_usd)

    respond_to do |format|
      format.html do
        @pagy, @installments = pagy(:offset, scope)
        @installment_totals = total_installments_for(@installments)
      end
      format.csv { send_csv("cuentas-por-cobrar", CSV_HEADERS, ar_csv_rows(scope)) }
    end
  end

  private

  # Total number of installments per sale, in ONE grouped query (for the "N°
  # actual/total" column). Returns { sale_id => Integer }.
  def total_installments_for(installments)
    sale_ids = installments.map(&:sale_id).uniq
    Installment.where(sale_id: sale_ids).group(:sale_id).count
  end

  def ar_csv_rows(scope)
    rows = scope.to_a
    totals = total_installments_for(rows)
    rows.map do |inst|
      [
        inst.sale.client.full_name,
        inst.sale.correlative,
        "#{inst.installment_number}/#{totals[inst.sale_id]}",
        inst.amount_usd,
        inst.balance_usd,
        helpers.format_date(inst.due_date),
        inst.overdue? ? "Vencida" : "Pendiente"
      ]
    end
  end

  # Filters the outstanding-installments scope, mirroring the sales toolbar:
  # - q: client name OR sale correlative (ILIKE)
  # - status (estado): vencida (past due) / pendiente (not yet due) within outstanding
  # - date_range / on (vencimiento by calendar range or specific day)
  # - due_within (vence dentro de N días)
  def filter_installments(scope)
    if params[:q].present?
      scope = scope.references(:sales, :clients)
                   .where("clients.full_name ILIKE :q OR sales.correlative ILIKE :q", q: "%#{params[:q]}%")
    end

    case params[:status]
    when "vencida"   then scope = scope.where("due_date < ?", Date.current)
    when "pendiente" then scope = scope.where("due_date >= ?", Date.current)
    end

    range = DateRange.for_day(params[:on]) || DateRange.for(params[:date_range])
    scope = scope.where(due_date: range) if range

    upcoming = DateRange.upcoming(params[:due_within])
    scope = scope.where(due_date: upcoming) if upcoming

    scope
  end
end
