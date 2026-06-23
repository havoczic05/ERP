class AccountsReceivableController < ApplicationController
  # GET /accounts_receivable
  def index
    authorize Amortization, :index?
    scope = filter_installments(Installment.outstanding.includes(sale: :client))
    @subtotal = scope.sum(:balance_usd)
    @pagy, @installments = pagy(:offset, scope)
  end

  private

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
