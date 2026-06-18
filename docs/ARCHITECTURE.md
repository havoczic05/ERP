# Architecture Overview

A concise map of how this ERP is built. It documents the conventions that
already exist in the code — patterns proven across the six PRD modules — so new
work stays consistent. This is descriptive, not aspirational.

## What this is

A **single-company** web ERP for an electronics-components importer. It centralizes
three operational pillars: inventory control, the sales/quotation cycle, and
accounts receivable with installment-based credit. Currency is **USD** throughout.

> Single-company by design: there is no multi-tenant layer. The inventory model
> allows multiple warehouses for future scalability, but the business runs one.

## Tech stack

| Concern | Choice |
| --- | --- |
| Framework | Ruby on Rails 8.1 (Ruby 3.4) |
| Database | PostgreSQL |
| Asset pipeline | Propshaft (no bundler) |
| JavaScript | importmap-rails + Hotwire (Turbo + Stimulus) |
| Background/infra | Solid Queue / Solid Cache / Solid Cable, Puma |
| Authorization | Pundit |
| Pagination | Pagy |
| PDF | Prawn + prawn-table (pure Ruby) |
| Testing | RSpec + FactoryBot |

## Domain model

```
User (administrador | vendedor)        CompanySettings (singleton + logo)

Client ─< Sale >─ Warehouse
            │  └─ document_type: cotizacion | venta
            │  └─ status: confirmada | anulada   (soft-deleted via discarded_at)
            ├─< SaleItem >── Product (stock, base_price_usd)
            ├─< Installment ─< Amortization
            └─ CreditNote (1:1, generated on annulment)
```

- A **cotización** can convert to a **venta** (`source_cotizacion_id` links back).
- Annulling a venta restores stock, voids installments, and issues a CreditNote —
  all in one transaction; the record stays as historical `anulada`.

## Conventions & patterns

These are the load-bearing patterns. Follow them.

### Service objects (command pattern)
Multi-step writes live in `app/services/` as a PORO with a class-level entry point
and a **Result PORO** — `result.success?` / `result.<record>` / `result.errors`.
The whole operation is wrapped in `ActiveRecord::Base.transaction`, using
`raise ActiveRecord::Rollback` on validation failure and per-row `#with_lock`
(ascending id order) for concurrency safety.
Examples: `SaleCreationService`, `SaleAnnulmentService`.

### Read/query objects
Read-side aggregation lives in its own PORO, kept pure and unit-testable, with
**injectable inputs** for determinism (e.g. `DashboardMetrics.new(today:)`).
Controllers stay thin: instantiate and assign.

### Document rendering
Output documents are POROs too — `SalePdf < Prawn::Document` in `app/pdfs/`.
Rendered server-side, no view context (formatting helpers are duplicated locally).

### Authentication
Session-cookie auth. `current_user` reads `session[:user_id]`; an
`authenticate_user!` before_action redirects to login when absent. Two roles:
`administrador`, `vendedor` (`User#admin?` / `#vendedor?`).

### Authorization (Pundit)
One policy per resource in `app/policies/`. `ApplicationController` rescues
`Pundit::NotAuthorizedError` → `head :forbidden`. Admin-only resources mirror the
`ADMIN_ROLE`/`admin?` shape (see `CompanySettingsPolicy`, `DashboardPolicy`).
Record-less views use **headless authorization**: `authorize :dashboard, :show?`.

### Soft delete
`discarded_at` timestamp + explicit `kept` / `discarded` scopes and
`discard` / `undiscard` / `discarded?` methods. **No `default_scope`** — callers
opt in (e.g. `Sale.kept`). DB partial unique indexes (`WHERE discarded_at IS NULL`)
back the model-level uniqueness for race safety.

### Enums & money
Enums are **string-backed** (`enum :status, { confirmada: "confirmada", ... }`).
Money is `decimal(10,2)` in USD, displayed with `number_to_currency(x, unit: "USD ")`.

### Directory layout
`app/services` (commands + query objects) · `app/policies` (Pundit) ·
`app/pdfs` (Prawn docs) · `app/helpers` (view + SVG rendering).

## Key architectural decision: server-side rendering, no headless browser

**Context.** The CI/WSL2 environment has **no Chrome/Chromium**. JS-driven system
behaviors are therefore not covered by automated specs ("W-3 debt"; see
`spec/system/sales_spec.rb`).

**Decision.** Generate visual artifacts **server-side**, with no headless-browser
dependency:
- **PDFs** use Prawn (pure Ruby), not wicked_pdf/grover (which need Chromium).
- **Dashboard charts** are inline **SVG** rendered by a helper, not Chartkick/Chart.js.

**Why.** A Chromium-based approach would be untestable in CI and would re-introduce
the exact fragility the project works to avoid. Server-rendered output is fully
covered by `rack_test`. This decision held independently across two modules
(RF5.4 PDF and §3.6 Dashboard) — treat it as a principle, not a one-off.

## Testing & delivery

- **Strict TDD** (red → green), `bundle exec rspec`. Specs are split into
  `spec/models`, `spec/services`, `spec/requests`, `spec/system` (driven by
  `rack_test`). `login_as` stubs `current_user`.
- **CI gates** (GitHub Actions, all required to merge): `lint` (rubocop-rails-omakase),
  `scan_ruby` (Brakeman), `scan_js` (importmap audit), `test` (RSpec).
- **GitHub Flow**: protected `main`, squash-only merges, conventional commits.

## Non-functional guarantees (PRD §5)

- **USD only** for all financial persistence and computation.
- **Transactional integrity**: stock changes + sale/installment creation are atomic.
- **E-invoicing ready**: sales carry `billing_status` (enum) and
  `billing_response_metadata` (jsonb) so a future electronic-invoicing integration
  needs no schema change.
