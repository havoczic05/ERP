# AmortizationCreationService — records a payment against an installment.
#
# Concurrency strategy (ADR-003):
#   installment.with_lock reloads the row with SELECT ... FOR UPDATE, giving
#   a fresh balance_usd inside the lock. Overpayment is rejected against that
#   fresh value before any write, so balance can never go negative.
#
# Money precision (ADR-003):
#   All arithmetic is done in BigDecimal. The incoming amount is coerced with
#   BigDecimal(amount.to_s) to avoid Float contamination.
#
# Returns a Result PORO:
#   success → result.record is the persisted Amortization
#   failure → result.record is the Installment, result.errors has messages
class AmortizationCreationService
  def self.call(installment, amount:, paid_at: Time.current, notes: nil)
    new(installment, amount: amount, paid_at: paid_at, notes: notes).call
  end

  def initialize(installment, amount:, paid_at: Time.current, notes: nil)
    @installment = installment
    @amount      = BigDecimal(amount.to_s)
    @paid_at     = paid_at
    @notes       = notes
    @errors      = []
  end

  def call
    # Early guards (outside transaction — fast path, no lock needed)
    if @amount <= 0
      return Result.failure(@installment, ['Amount must be greater than 0'])
    end

    unless @installment.pendiente?
      return Result.failure(@installment, ['Installment is not open for payment'])
    end

    result = nil

    ActiveRecord::Base.transaction do
      @installment.with_lock do
        # Reload gives us fresh balance_usd after acquiring the row lock.
        balance = BigDecimal(@installment.balance_usd.to_s)

        if @amount > balance
          @errors = ['Amount exceeds outstanding balance']
          raise ActiveRecord::Rollback
        end

        amortization = @installment.amortizations.create!(
          amount_usd: @amount,
          paid_at:    @paid_at,
          notes:      @notes
        )

        new_balance = balance - @amount
        @installment.update!(
          balance_usd: new_balance,
          status:      new_balance.zero? ? 'pagada' : 'pendiente'
        )

        result = Result.success(amortization)
      end
    end

    result || Result.failure(@installment, @errors)
  rescue ActiveRecord::RecordInvalid => e
    Result.failure(@installment, [e.message])
  rescue ActiveRecord::StatementInvalid => e
    Result.failure(@installment, [e.message])
  end
end
