require 'rails_helper'

RSpec.describe 'sale error partials', type: :view do
  describe '_field_error' do
    it 'renders nothing when messages are empty' do
      render partial: 'sales/field_error', locals: { messages: [] }
      expect(rendered).to be_empty
    end

    it 'renders nothing when messages is nil' do
      render partial: 'sales/field_error', locals: { messages: nil }
      expect(rendered).to be_empty
    end

    it 'renders a div.field-error with each message' do
      render partial: 'sales/field_error', locals: { messages: [ "Cliente es requerido" ] }

      expect(rendered).to have_css('div.field-error', text: "Cliente es requerido")
    end

    it 'renders multiple messages' do
      render partial: 'sales/field_error', locals: { messages: [ "Error uno", "Error dos" ] }

      expect(rendered).to have_css('div.field-error', count: 2)
      expect(rendered).to include("Error uno")
      expect(rendered).to include("Error dos")
    end
  end

  describe '_section_error' do
    it 'renders nothing when messages are empty' do
      render partial: 'sales/section_error', locals: { messages: [] }
      expect(rendered).to be_empty
    end

    it 'renders nothing when messages is nil' do
      render partial: 'sales/section_error', locals: { messages: nil }
      expect(rendered).to be_empty
    end

    it 'renders a banner with an alert icon and a list of messages' do
      render partial: 'sales/section_error',
             locals: { messages: [ "La suma de cuotas no coincide" ] }

      expect(rendered).to have_css('.section-error-banner')
      expect(rendered).to have_css('.section-error-banner__icon')
      expect(rendered).to have_css('li', text: "La suma de cuotas no coincide")
    end

    it 'renders multiple messages in a list' do
      render partial: 'sales/section_error',
             locals: { messages: [ "Cuota 1 inválida", "Monto negativo" ] }

      expect(rendered).to have_css('li', count: 2)
    end

    it 'uses Spanish label text' do
      render partial: 'sales/section_error',
             locals: { messages: [ "Error de cuotas" ] }

      expect(rendered).to include('Error en plan de cuotas')
    end
  end
end
