require "rails_helper"
require "pdf/inspector"

RSpec.describe SalePdf do
  let(:warehouse) { create(:warehouse) }
  let(:client) do
    create(:client, :ruc_client, full_name: "Cliente Mayorista SAC",
           document_number: "20987654321")
  end
  let(:product) { create(:product, name: "Resistor 10k", warehouse: warehouse) }
  let(:settings) { CompanySettings.instance }

  def text_of(pdf_string)
    PDF::Inspector::Text.analyze(pdf_string).strings.join(" ")
  end

  before do
    settings.update!(razon_social: "Importadora Electrónica SAC", ruc: "20123456789")
  end

  describe "#render" do
    let(:sale) do
      sale = create(:sale, client: client, warehouse: warehouse,
                    subtotal_usd: 30.00, tax_usd: 0.00, total_usd: 30.00)
      create(:sale_item, sale: sale, product: product, quantity: 3,
             unit_price_usd: 10.00, line_total_usd: 30.00)
      sale
    end

    it "returns a valid PDF byte string" do
      pdf = described_class.new(sale, settings).render
      expect(pdf).to start_with("%PDF")
    end

    it "injects the company razon_social and RUC into the header (RF5.4)" do
      text = text_of(described_class.new(sale, settings).render)
      expect(text).to include("Importadora Electrónica SAC")
      expect(text).to include("20123456789")
    end

    it "renders the document type label and correlative" do
      text = text_of(described_class.new(sale, settings).render)
      expect(text).to include(sale.correlative)
      expect(text).to match(/Cotizacion/i)
    end

    it "renders client identification" do
      text = text_of(described_class.new(sale, settings).render)
      expect(text).to include("Cliente Mayorista SAC")
      expect(text).to include("20987654321")
    end

    it "renders line items and totals" do
      text = text_of(described_class.new(sale, settings).render)
      expect(text).to include("Resistor 10k")
      expect(text).to include("3")               # quantity
      expect(text).to include("USD 30.00")       # total
    end

    it "does not render an Impuesto line" do
      text = text_of(described_class.new(sale, settings).render)
      expect(text).not_to include("Impuesto")
    end
  end

  describe "venta with installments" do
    # Anchor the due date far from "today" so it can never collide with the
    # sale's emission date in the PDF header (which renders today's date) —
    # otherwise the "omit" assertion breaks whenever the suite runs on that day.
    let(:due_date) { Date.current + 200 }
    let(:due_date_str) { due_date.strftime("%d/%m/%Y") }

    let(:venta) do
      sale = create(:sale, :venta, client: client, warehouse: warehouse,
                    subtotal_usd: 20.00, total_usd: 20.00)
      create(:sale_item, sale: sale, product: product, quantity: 2,
             unit_price_usd: 10.00, line_total_usd: 20.00)
      create(:installment, sale: sale, installment_number: 1,
             amount_usd: 20.00, balance_usd: 20.00, due_date: due_date)
      sale
    end

    it "renders the installments section" do
      text = text_of(described_class.new(venta, settings).render)
      expect(text).to match(/Venta/i)
      expect(text).to include(due_date_str)
    end

    it "omits the installments section when show_installments is false" do
      text = text_of(described_class.new(venta, settings, show_installments: false).render)
      expect(text).not_to include("Cuotas")
      expect(text).not_to include(due_date_str)
      # the rest of the document still renders
      expect(text).to include(venta.correlative)
      expect(text).to include("Resistor 10k")
    end
  end

  describe "annulled document" do
    let(:anulada) do
      sale = create(:sale, :venta, :anulada, client: client, warehouse: warehouse,
                    subtotal_usd: 20.00, total_usd: 20.00)
      create(:sale_item, sale: sale, product: product)
      sale
    end

    it "marks the document as Anulada" do
      text = text_of(described_class.new(anulada, settings).render)
      expect(text).to match(/Anulada/i)
    end
  end

  describe "logo handling" do
    let(:sale) do
      sale = create(:sale, client: client, warehouse: warehouse)
      create(:sale_item, sale: sale, product: product)
      sale
    end

    it "embeds the logo when attached" do
      settings.logo.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/logo.png")),
        filename: "logo.png", content_type: "image/png"
      )
      expect { described_class.new(sale, settings).render }.not_to raise_error
    end

    it "renders without a logo when none is attached" do
      expect(settings.logo).not_to be_attached
      expect { described_class.new(sale, settings).render }.not_to raise_error
    end
  end

  describe "branding additions (subtitulo, sku, bank footer)" do
    let(:sale) do
      sale = create(:sale, client: client, warehouse: warehouse)
      create(:sale_item, sale: sale, product: product)
      sale
    end

    it "renders the company subtitulo when present" do
      settings.update!(subtitulo: "Importadora y Distribuidora")
      text = text_of(described_class.new(sale, settings).render)
      expect(text).to include("Importadora y Distribuidora")
    end

    it "renders the product sku as the CÓDIGO column" do
      text = text_of(described_class.new(sale, settings).render)
      expect(text).to include(product.sku)
    end

    it "renders bank accounts in the footer when present" do
      settings.bank_accounts.create!(bank: "BCP", currency_label: "Dólares",
                                     account_number: "193-9852295-1-39")
      text = text_of(described_class.new(sale, settings).render)
      expect(text).to include("BCP")
      expect(text).to include("193-9852295-1-39")
    end

    it "renders without bank accounts" do
      expect(settings.bank_accounts).to be_empty
      expect { described_class.new(sale, settings).render }.not_to raise_error
    end
  end

  describe "optional company fields" do
    let(:sale) do
      sale = create(:sale, client: client, warehouse: warehouse)
      create(:sale_item, sale: sale, product: product)
      sale
    end

    it "renders when direccion and telefono are nil" do
      settings.update!(direccion: nil, telefono: nil)
      expect { described_class.new(sale, settings).render }.not_to raise_error
    end

    it "renders direccion and telefono when present" do
      settings.update!(direccion: "Av. Comercio 123", telefono: "555-1234")
      text = text_of(described_class.new(sale, settings).render)
      expect(text).to include("Av. Comercio 123")
      expect(text).to include("555-1234")
    end
  end
end
