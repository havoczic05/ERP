# ERP — Project Conventions

## UI Language (MANDATORY for all views/components)

All user-facing UI text in this app is **Spanish, hardcoded** directly in views,
controllers, and models. This app is single-language (Peruvian ERP; end users
speak only Spanish). **Do NOT introduce i18n** (no `es.yml`, no `t()` lazy
lookup, no `rails-i18n` gem) — it was deliberately rejected as over-engineering.

When creating or editing ANY view, component, partial, flash message, or model:

- All visible text MUST be in Spanish.
- **Keep the word "Dashboard" as "Dashboard"** (it is not translated).
- Validation messages are translated with per-validation `message:` overrides in
  the model (e.g. `validates :name, presence: { message: "no puede estar en blanco" }`).
  Do not use i18n for this.
- Do NOT translate: HTML `id` attributes, CSS classes, input `name` attributes
  (e.g. `sale[items][][product_id]`), route paths, or route helpers.
- System specs MUST assert Spanish text and use Spanish labels in `fill_in`.

### Canonical glossary

| English | Spanish | English | Spanish |
|---|---|---|---|
| Clients | Clientes | New | Nuevo / Nueva (gender agreement) |
| Sales | Ventas | Edit | Editar |
| Products | Productos | Create | Crear |
| Warehouses | Almacenes | Update | Actualizar |
| Users | Usuarios | Delete | Eliminar |
| Accounts Receivable | Cuentas por Cobrar | Archive | Archivar |
| Company Settings | Configuración | View / Show | Ver |
| Dashboard | Dashboard (kept) | Back to X | Volver a X |
| Full name | Nombre completo | Search | Buscar |
| Document number | Número de documento | Log in / out | Iniciar / Cerrar sesión |
| Phone | Teléfono | Installments | Cuotas |
| Actions | Acciones | Record Payment | Registrar pago |
