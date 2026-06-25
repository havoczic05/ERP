require 'rails_helper'

RSpec.describe AmortizationCreationService do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------
  def call(installment, amount:, paid_at: Time.current)
    described_class.call(installment, amount: amount, paid_at: paid_at)
  end

  # ---------------------------------------------------------------------------
  # AR-05 — zero / negative amount guard
  # ---------------------------------------------------------------------------
  describe 'AR-05: zero/negative amount guard' do
    let(:installment) { create(:installment, status: 'pendiente', amount_usd: 100, balance_usd: 100) }

    it 'returns failure when amount is 0' do
      result = call(installment, amount: 0)
      expect(result).to be_failure
      expect(result.errors).not_to be_empty
    end

    it 'does not create an Amortization when amount is 0' do
      expect { call(installment, amount: 0) }.not_to change(Amortization, :count)
    end

    it 'returns failure when amount is negative' do
      result = call(installment, amount: -50)
      expect(result).to be_failure
      expect(result.errors).not_to be_empty
    end

    it 'does not create an Amortization when amount is negative' do
      expect { call(installment, amount: -50) }.not_to change(Amortization, :count)
    end
  end

  # ---------------------------------------------------------------------------
  # AR-04 — overpayment guard
  # ---------------------------------------------------------------------------
  describe 'AR-04: overpayment guard' do
    let(:installment) { create(:installment, status: 'pendiente', amount_usd: 100, balance_usd: 100) }

    it 'returns failure when amount exceeds balance_usd' do
      result = call(installment, amount: 150)
      expect(result).to be_failure
      expect(result.errors).not_to be_empty
    end

    it 'does not create an Amortization on overpayment' do
      expect { call(installment, amount: 150) }.not_to change(Amortization, :count)
    end

    it 'leaves balance_usd unchanged on overpayment' do
      call(installment, amount: 150)
      expect(installment.reload.balance_usd).to eq(BigDecimal('100.00'))
    end

    it 'leaves status as pendiente on overpayment' do
      call(installment, amount: 150)
      expect(installment.reload.status).to eq('pendiente')
    end
  end

  # ---------------------------------------------------------------------------
  # AR-02 — full payment → pagada + balance 0
  # ---------------------------------------------------------------------------
  describe 'AR-02: full payment' do
    let(:installment) { create(:installment, status: 'pendiente', amount_usd: 500, balance_usd: 500) }

    it 'returns success' do
      result = call(installment, amount: 500)
      expect(result).to be_success
    end

    it 'creates exactly one Amortization' do
      expect { call(installment, amount: 500) }.to change(Amortization, :count).by(1)
    end

    it 'sets balance_usd to exactly 0' do
      call(installment, amount: 500)
      expect(installment.reload.balance_usd).to eq(BigDecimal('0'))
    end

    it 'flips status to pagada' do
      call(installment, amount: 500)
      expect(installment.reload.status).to eq('pagada')
    end

    it 'returns the amortization as result.record' do
      result = call(installment, amount: 500)
      expect(result.record).to be_a(Amortization)
      expect(result.record).to be_persisted
    end
  end

  # ---------------------------------------------------------------------------
  # AR-03 — partial payment → pendiente + reduced balance
  # ---------------------------------------------------------------------------
  describe 'AR-03: partial payment' do
    let(:installment) { create(:installment, status: 'pendiente', amount_usd: 500, balance_usd: 500) }

    it 'returns success' do
      result = call(installment, amount: 200)
      expect(result).to be_success
    end

    it 'creates exactly one Amortization' do
      expect { call(installment, amount: 200) }.to change(Amortization, :count).by(1)
    end

    it 'decrements balance_usd by the amount paid' do
      call(installment, amount: 200)
      expect(installment.reload.balance_usd).to eq(BigDecimal('300.00'))
    end

    it 'keeps status as pendiente' do
      call(installment, amount: 200)
      expect(installment.reload.status).to eq('pendiente')
    end
  end

  # ---------------------------------------------------------------------------
  # AR-07 + ADR-003 — with_lock is invoked (concurrency guard)
  # ---------------------------------------------------------------------------
  describe 'AR-07: with_lock concurrency guard' do
    let(:installment) { create(:installment, status: 'pendiente', amount_usd: 300, balance_usd: 300) }

    it 'calls with_lock on the installment' do
      expect(installment).to receive(:with_lock).and_call_original
      call(installment, amount: 100)
    end

    it 'rejects a second payment that would exceed the remaining balance (logical oversell)' do
      # First payment: 200 of 300
      call(installment, amount: 200)
      installment.reload  # balance is now 100

      # Second payment: 150 → exceeds remaining 100 → must be rejected
      result = call(installment, amount: 150)
      expect(result).to be_failure
      expect(installment.reload.balance_usd).to eq(BigDecimal('100.00'))
    end
  end

  # ---------------------------------------------------------------------------
  # ADR-003 — BigDecimal precision
  # ---------------------------------------------------------------------------
  describe 'ADR-003: BigDecimal precision' do
    let(:installment) { create(:installment, status: 'pendiente', amount_usd: 1, balance_usd: 1) }

    it 'stores amount_usd as exact decimal (not Float-contaminated)' do
      result = call(installment, amount: '0.10')
      expect(result.record.amount_usd).to eq(BigDecimal('0.10'))
    end
  end
end
