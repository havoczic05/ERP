FactoryBot.define do
  factory :company_settings do
    razon_social { "Empresa SAC" }
    ruc          { "20123456789" }
    direccion    { nil }
    telefono     { nil }
  end
end
