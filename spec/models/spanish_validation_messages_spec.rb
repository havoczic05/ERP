require "rails_helper"

RSpec.describe "Spanish validation messages", type: :model do
  it "Product: attribute names and messages are Spanish" do
    p = Product.new
    p.valid?
    expect(p.errors.full_messages).to include(
      "Nombre no puede estar en blanco",
      "SKU no puede estar en blanco",
      "Marca no puede estar en blanco",
      "Precio base (USD) debe ser mayor que 0",
      "Almacén debe existir"
    )
    expect(p.errors.full_messages.join).not_to match(/must exist|can't be blank|is not|greater than/i)
  end

  it "User: role inclusion message is Spanish" do
    u = User.new(email: "x@y.com", role: "bogus")
    u.valid?
    expect(u.errors.full_messages).to include("Rol no es válido")
  end

  it "Sale: presence/association messages are Spanish" do
    s = Sale.new
    s.valid?
    msgs = s.errors.full_messages.join("\n")
    expect(msgs).to include("Cliente debe existir")
    expect(msgs).to include("Almacén debe existir")
    expect(msgs).to include("Tipo de documento no puede estar en blanco")
    expect(msgs).not_to match(/must exist|can't be blank/i)
  end

  it "Sale: correlative uniqueness message is Spanish" do
    existing = create(:sale)
    dup = build(:sale, correlative: existing.correlative)
    dup.valid?
    expect(dup.errors.full_messages).to include("Correlativo ya está en uso")
    expect(dup.errors.full_messages.join).not_to match(/has already been taken/i)
  end

  it "SaleItem: numericality and association messages are Spanish" do
    si = SaleItem.new(quantity: 0, unit_price_usd: 0, line_total_usd: -1)
    si.valid?
    msgs = si.errors.full_messages.join("\n")
    expect(msgs).to include("Venta debe existir", "Producto debe existir")
    expect(msgs).to match(/Cantidad debe ser mayor que 0/)
    expect(msgs).not_to match(/must exist|greater than|must be/i)
  end

  it "Installment: messages are Spanish" do
    i = Installment.new(amount_usd: 0, balance_usd: -1)
    i.valid?
    expect(i.errors.full_messages.join("\n")).not_to match(/must exist|can't be blank|greater than/i)
  end

  it "Amortization: messages are Spanish" do
    a = Amortization.new(amount_usd: 0)
    a.valid?
    msgs = a.errors.full_messages.join("\n")
    expect(msgs).to include("Cuota debe existir")
    expect(msgs).to include("Monto (USD) debe ser mayor que 0")
    expect(msgs).not_to match(/must exist|can't be blank|greater than/i)
  end

  it "CreditNote: messages are Spanish" do
    cn = CreditNote.new(total_usd: 0)
    cn.valid?
    msgs = cn.errors.full_messages.join("\n")
    expect(msgs).to include("Venta debe existir")
    expect(msgs).to include("Total (USD) debe ser mayor que 0")
    expect(msgs).not_to match(/must exist|can't be blank|greater than/i)
  end
end
