class AccountsReceivableController < ApplicationController
  # GET /accounts_receivable
  def index
    authorize Amortization, :index?
    @pagy, @installments = pagy(:offset, Installment.outstanding.includes(sale: :client))
  end
end
