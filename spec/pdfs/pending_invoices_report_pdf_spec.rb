require "rails_helper"
require "pdf/inspector"

RSpec.describe PendingInvoicesReportPdf do
  let(:settings)  { CompanySettings.instance }
  let(:warehouse) { create(:warehouse) }
  let(:client_a) do
    create(:client, :ruc_client, full_name: "Tecno Núñez SA", document_number: "20518536363")
  end

  def text_of(pdf_string)
    PDF::Inspector::Text.analyze(pdf_string).strings.join(" ")
  end

  def overdue_installment_for(client, correlative:, balance:)
    sale = create(:sale, :venta, client: client, warehouse: warehouse, correlative: correlative)
    create(:installment, sale: sale, installment_number: 1, status: "pendiente",
           due_date: 5.days.ago, amount_usd: balance, balance_usd: balance)
  end

  before do
    settings.update!(razon_social: "Grupo Ampers SAC", ruc: "20123456789")
  end

  it "returns a valid PDF byte string" do
    inst = overdue_installment_for(client_a, correlative: "VTA-00078", balance: 148.50)
    pdf = described_class.new([ inst ], { inst.sale_id => 148.50 }, settings).render
    expect(pdf).to start_with("%PDF")
  end

  it "renders the client identity, invoice rows and the pending total" do
    inst = overdue_installment_for(client_a, correlative: "VTA-00078", balance: 148.50)
    text = text_of(described_class.new([ inst ], { inst.sale_id => 148.50 }, settings).render)
    expect(text).to include("Tecno Núñez SA")
    expect(text).to include("20518536363")
    expect(text).to include("VTA-00078")
    expect(text).to include("Vencida")
    expect(text).to include("TOTAL PENDIENTE")
    expect(text).to include("USD 148.50")
  end

  it "groups by client when several are present" do
    client_b = create(:client, :ruc_client, full_name: "Jireh Electronics SAC",
                                             document_number: "20518536999")
    a = overdue_installment_for(client_a, correlative: "VTA-00078", balance: 148.50)
    b = overdue_installment_for(client_b, correlative: "VTA-00090", balance: 200.00)
    balances = { a.sale_id => 148.50, b.sale_id => 200.00 }

    text = text_of(described_class.new([ a, b ], balances, settings).render)
    expect(text).to include("Tecno Núñez SA")
    expect(text).to include("Jireh Electronics SAC")
  end

  it "renders the bank footer when accounts exist" do
    settings.bank_accounts.create!(bank: "BCP", account_number: "193-9852295-1-39")
    inst = overdue_installment_for(client_a, correlative: "VTA-00078", balance: 148.50)
    text = text_of(described_class.new([ inst ], { inst.sale_id => 148.50 }, settings).render)
    expect(text).to include("BCP")
    expect(text).to include("193-9852295-1-39")
  end
end
