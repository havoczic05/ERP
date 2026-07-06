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
    context 'when installment status is pendiente (not overdue)' do
      let(:installment) { instance_double('Installment', status: 'pendiente', overdue?: false) }

      it 'returns a span with badge--warning class' do
        result = helper.installment_status_badge(installment)
        expect(result).to include('badge--warning')
      end

      it 'returns a span with the Spanish status text' do
        result = helper.installment_status_badge(installment)
        expect(result).to include('Pendiente')
      end

      it 'returns html_safe output' do
        result = helper.installment_status_badge(installment)
        expect(result).to be_html_safe
      end
    end

    context 'when installment is pendiente but overdue' do
      let(:installment) { instance_double('Installment', status: 'pendiente', overdue?: true) }

      it 'renders the Vencida label with the danger variant' do
        result = helper.installment_status_badge(installment)
        expect(result).to include('badge--danger')
        expect(result).to include('Vencida')
      end
    end

    context 'when installment status is pagada' do
      let(:installment) { instance_double('Installment', status: 'pagada', overdue?: false) }

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
      let(:installment) { instance_double('Installment', status: 'vencida', overdue?: false) }

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
      let(:installment) { instance_double('Installment', status: 'anulada', overdue?: false) }

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

  # ---------------------------------------------------------------------------
  # icon — inline SVG from a curated set (no gem, no Node)
  # ---------------------------------------------------------------------------
  describe '#icon' do
    it 'returns an inline SVG for a known icon name' do
      svg = helper.icon(:eye)
      expect(svg).to include('<svg')
      expect(svg).to include('aria-hidden="true"')
      expect(svg).to be_html_safe
    end

    it 'accepts a string name' do
      expect(helper.icon('trash')).to include('<svg')
    end

    it 'returns nil for an unknown icon name' do
      expect(helper.icon(:does_not_exist)).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # action_link / action_button — shared, consistent action controls
  # Visible Spanish labels MUST be preserved (system specs depend on them).
  # ---------------------------------------------------------------------------
  describe '#action_link' do
    it 'renders an anchor with the ghost + small button classes by default' do
      html = helper.action_link('Ver', '/products/1')
      expect(html).to have_link('Ver', href: '/products/1')
      expect(html).to include('btn')
      expect(html).to include('btn--ghost')
      expect(html).to include('btn--sm')
    end

    it 'applies the danger variant' do
      html = helper.action_link('Eliminar', '/products/1', variant: :danger)
      expect(html).to include('btn--danger')
      expect(html).not_to include('btn--ghost')
    end

    it 'applies the primary variant with no neutral/danger modifier' do
      html = helper.action_link('Nuevo', '/products/new', variant: :primary)
      expect(html).to include('btn')
      expect(html).not_to include('btn--ghost')
      expect(html).not_to include('btn--danger')
    end

    it 'omits the small modifier when size is :md' do
      html = helper.action_link('Nuevo', '/products/new', variant: :primary, size: :md)
      expect(html).not_to include('btn--sm')
    end

    it 'prepends an icon when given' do
      html = helper.action_link('Ver', '/products/1', icon: :eye)
      expect(html).to include('<svg')
      expect(html).to have_link('Ver')
    end

    it 'preserves the exact visible label' do
      expect(helper.action_link('Editar', '/products/1')).to have_link('Editar')
    end
  end

  describe '#action_button' do
    it 'renders a button_to form with the danger + small classes by default' do
      html = helper.action_button('Eliminar', '/products/1', method: :delete)
      expect(html).to have_button('Eliminar')
      expect(html).to include('btn--danger')
      expect(html).to include('btn--sm')
    end

    it 'sets a non-GET HTTP method via the hidden _method field' do
      html = helper.action_button('Eliminar', '/products/1', method: :delete)
      expect(html).to include('name="_method"')
      expect(html).to include('value="delete"')
    end

    it 'adds a turbo confirm dialog when confirm is given' do
      html = helper.action_button('Eliminar', '/products/1', method: :delete,
                                   confirm: '¿Eliminar este producto?')
      expect(html).to include('data-turbo-confirm="¿Eliminar este producto?"')
    end

    it 'prepends an icon when given' do
      html = helper.action_button('Eliminar', '/products/1', method: :delete, icon: :trash)
      expect(html).to include('<svg')
      expect(html).to have_button('Eliminar')
    end
  end

  # ---------------------------------------------------------------------------
  # format_date — dd/mm/aaaa in the app's local time zone (no i18n)
  # ---------------------------------------------------------------------------
  describe '#format_date' do
    it 'formats a time as dd/mm/aaaa' do
      expect(helper.format_date(Time.zone.local(2026, 6, 22, 20, 0))).to eq('22/06/2026')
    end

    it 'formats a date as dd/mm/aaaa' do
      expect(helper.format_date(Date.new(2026, 1, 5))).to eq('05/01/2026')
    end

    it 'returns an empty string for nil' do
      expect(helper.format_date(nil)).to eq('')
    end
  end

  # ---------------------------------------------------------------------------
  describe '#sale_installment_rows' do
    let(:warehouse) { create(:warehouse) }
    let(:client)    { create(:client, :ruc_client) }
    let(:sale) do
      create(:sale, :venta, client: client, warehouse: warehouse,
             subtotal_usd: 400.00, total_usd: 400.00)
    end

    it 'computes the running outstanding balance before each installment' do
      (1..4).each do |n|
        create(:installment, sale: sale, installment_number: n,
               amount_usd: 100.00, balance_usd: 100.00, status: 'pendiente',
               due_date: Date.new(2026, 8, 1) + (n - 1).months)
      end

      rows = helper.sale_installment_rows(sale)

      expect(rows.map { |r| r[:saldo_restante] })
        .to eq([ 400, 300, 200, 100 ].map { |n| BigDecimal(n) })
    end

    it 'returns the latest payment date per installment, or nil when unpaid' do
      paid = create(:installment, sale: sale, installment_number: 1,
                    amount_usd: 200.00, balance_usd: 0.00, status: 'pagada',
                    due_date: Date.new(2026, 8, 1))
      create(:amortization, installment: paid, amount_usd: 200.00,
             paid_at: Time.zone.local(2026, 8, 4, 10))
      create(:installment, sale: sale, installment_number: 2,
             amount_usd: 200.00, balance_usd: 200.00, status: 'pendiente',
             due_date: Date.new(2026, 9, 1))

      rows = helper.sale_installment_rows(sale)

      expect(rows.first[:paid_on]).to eq(Time.zone.local(2026, 8, 4, 10))
      expect(rows.second[:paid_on]).to be_nil
    end
  end
end
