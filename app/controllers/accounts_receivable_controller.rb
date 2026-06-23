class AccountsReceivableController < ApplicationController
  include CsvExport

  CSV_HEADERS = [ "Cliente", "Venta", "N° de cuota", "Cuotas pagadas", "Cuotas restantes",
                  "Monto (USD)", "Saldo (USD)", "Vencimiento", "Estado" ].freeze

  # GET /accounts_receivable
  def index
    authorize Amortization, :index?
    scope = filter_installments(Installment.outstanding.includes(sale: :client))
    @subtotal = scope.sum(:balance_usd)

    respond_to do |format|
      format.html do
        @pagy, @installments = pagy(:offset, scope)
        @installment_progress = installment_progress_for(@installments)
      end
      format.csv { send_csv("cuentas-por-cobrar", CSV_HEADERS, ar_csv_rows(scope)) }
    end
  end

  private

  # Per-sale installment progress for the given installments, in ONE grouped
  # query (avoids N+1 and the row-multiplication that joining installments into
  # the listing scope would cause on the SUM).
  # Returns { sale_id => { paid: Integer, pending: Integer } }.
  def installment_progress_for(installments)
    sale_ids = installments.map(&:sale_id).uniq
    counts = Installment.where(sale_id: sale_ids).group(:sale_id, :status).count
    sale_ids.index_with do |sale_id|
      { paid: counts[[ sale_id, "pagada" ]] || 0, pending: counts[[ sale_id, "pendiente" ]] || 0 }
    end
  end

  def ar_csv_rows(scope)
    rows = scope.to_a
    progress = installment_progress_for(rows)
    rows.map do |inst|
      p = progress[inst.sale_id]
      [
        inst.sale.client.full_name,
        inst.sale.correlative,
        inst.installment_number,
        p[:paid],
        p[:pending],
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
