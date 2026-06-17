class AmortizationsController < ApplicationController
  before_action :set_installment

  # POST /installments/:installment_id/amortizations
  def create
    authorize Amortization, :create?

    result = AmortizationCreationService.call(
      @installment,
      amount: amortization_params[:amount_usd],
      notes:  amortization_params[:notes]
    )

    if result.success?
      redirect_to accounts_receivable_path, notice: "Payment recorded."
    else
      flash[:alert] = result.errors.join("; ")
      redirect_back fallback_location: accounts_receivable_path
    end
  end

  private

  def set_installment
    @installment = Installment.find(params[:installment_id])
  end

  def amortization_params
    params.require(:amortization).permit(:amount_usd, :notes)
  end
end
