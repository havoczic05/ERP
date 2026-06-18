require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  # ---------------------------------------------------------------------------
  # sale_status_badge
  # ---------------------------------------------------------------------------
  describe '#sale_status_badge' do
    context 'when sale status is confirmada' do
      let(:sale) { instance_double('Sale', status: 'confirmada') }

      it 'returns a span with badge--success class' do
        result = helper.sale_status_badge(sale)
        expect(result).to include('badge--success')
      end

      it 'returns a span with humanized status text' do
        result = helper.sale_status_badge(sale)
        expect(result).to include('Confirmada')
      end

      it 'returns html_safe output' do
        result = helper.sale_status_badge(sale)
        expect(result).to be_html_safe
      end
    end

    context 'when sale status is anulada' do
      let(:sale) { instance_double('Sale', status: 'anulada') }

      it 'returns a span with badge--danger class' do
        result = helper.sale_status_badge(sale)
        expect(result).to include('badge--danger')
      end

      it 'returns a span with humanized status text' do
        result = helper.sale_status_badge(sale)
        expect(result).to include('Anulada')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # installment_status_badge
  # ---------------------------------------------------------------------------
  describe '#installment_status_badge' do
    context 'when installment status is pendiente' do
      let(:installment) { instance_double('Installment', status: 'pendiente') }

      it 'returns a span with badge--warning class' do
        result = helper.installment_status_badge(installment)
        expect(result).to include('badge--warning')
      end

      it 'returns a span with humanized status text' do
        result = helper.installment_status_badge(installment)
        expect(result).to include('Pendiente')
      end

      it 'returns html_safe output' do
        result = helper.installment_status_badge(installment)
        expect(result).to be_html_safe
      end
    end

    context 'when installment status is pagada' do
      let(:installment) { instance_double('Installment', status: 'pagada') }

      it 'returns a span with badge--success class' do
        result = helper.installment_status_badge(installment)
        expect(result).to include('badge--success')
      end

      it 'returns a span with humanized status text' do
        result = helper.installment_status_badge(installment)
        expect(result).to include('Pagada')
      end
    end

    context 'when installment status is vencida' do
      let(:installment) { instance_double('Installment', status: 'vencida') }

      it 'returns a span with badge--danger class' do
        result = helper.installment_status_badge(installment)
        expect(result).to include('badge--danger')
      end

      it 'returns a span with humanized status text' do
        result = helper.installment_status_badge(installment)
        expect(result).to include('Vencida')
      end
    end

    context 'when installment status is anulada' do
      let(:installment) { instance_double('Installment', status: 'anulada') }

      it 'returns a span with badge--danger class' do
        result = helper.installment_status_badge(installment)
        expect(result).to include('badge--danger')
      end

      it 'returns a span with humanized status text' do
        result = helper.installment_status_badge(installment)
        expect(result).to include('Anulada')
      end
    end
  end
end
