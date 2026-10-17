# Proposal: Responsive Tablet v1

## Intent

The tablet (768–900px) layout is broken in three concrete ways: (1) the sidebar collapses into a horizontal **top-strip** that eats ~30% of the viewport without showing data; (2) toolbar filters use `flex-wrap` and stack as a staircase; (3) the primary **"Nuevo X"** CTA is buried inside the toolbar instead of sitting in the page head beside the title. This change fixes all three on the five core index views so the tablet experience matches the desktop intent.

## Scope

### In Scope
- CSS: prune the 56rem top-strip block; extract the nav-drawer CSS from the 640px block into a new `@media (max-width: 900px)` block; add `.filters` CSS Grid for tablet.
- Views: move the **"Nuevo X"** `action_link` out of the toolbar and into the page head (`page-head--with-action`) on `sales`, `clients`, `products`, `users`, `warehouses` index templates.
- Reuse the existing `.page-head--with-action` pattern already defined at line 1115 of `app.css`.

### Out of Scope
- Mobile (<640px) layout beyond the drawer relocation.
- New components, JS, or Stimulus controllers.
- `accounts_receivable` index (no "Nuevo" CTA).
- Form views, show views, dashboard.

## Capabilities

> Research of `openspec/specs/` shows no existing specs. No spec-level behavior changes; this is a pure responsive presentation refactor.

### New Capabilities
- None

### Modified Capabilities
- None

## Approach

1. **CSS first.** Delete the `@media (max-width: 56rem)` top-strip block (≈ lines 446–511). Save the bytes.
2. **Move the drawer breakpoint.** Lift the existing nav-drawer block (hamburger + off-canvas) from `@media (max-width: 640px)` (≈2600–2682) into a single new `@media (max-width: 900px)` tablet block. Below 640px behavior is unchanged.
3. **Grid the filters.** Inside the new 900px block, set `.toolbar { flex-direction: column }` and `.filters { display: grid; grid-template-columns: repeat(3, 1fr); gap: var(--sp-3) }`. Submit + "Limpiar" stretch to span cleanly.
4. **Relocate the CTA.** In each of the 5 index views, pull the `action_link 'Nuevo ...'` out of `.toolbar` and render it inside `<div class="page-head page-head--with-action">` next to the `<h1>`. The `.fab` class + `fab` Stimulus wiring on the sales CTA is preserved as-is on the moved link.

A scratch `update_css.rb` already exists at repo root documenting this exact CSS transformation — treat it as a recipe, not a committed script.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `app/assets/stylesheets/app.css` | Modified | Delete 56rem block; add 900px drawer+grid block; remove drawer CSS from 640px block |
| `app/views/sales/index.html.erb` | Modified | Move "Nuevo documento" CTA into page head |
| `app/views/clients/index.html.erb` | Modified | Same for "Nuevo cliente" |
| `app/views/products/index.html.erb` | Modified | Same for "Nuevo producto" |
| `app/views/users/index.html.erb` | Modified | Same for "Nuevo usuario" |
| `app/views/warehouses/index.html.erb` | Modified | Same for "Nuevo almacén" |
| `update_css.rb` (repo root) | Removed | Throwaway scratch; delete after the CSS edit lands |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Existing 900px blocks (lines 1082, 1772) collide with new drawer block | Med | Append the new tablet block adjacent to existing ones; verify no duplicate selectors |
| `spec/system/*_index_spec.rb` match on CTA position inside `.toolbar` | Med | Grep test suite before moving; update selectors to `page-head` if needed |
| Line ranges in this brief drift from on-disk CSS | Low | Re-confirm line numbers at edit time (the brief's 2601–2682 vs actual 2600+) |
| The `.fab` + `fab` Stimulus controller breaks when CTA leaves the toolbar | Low | Keep `class: "fab"` and `data-controller` on the moved link |

## Rollback Plan

Pure CSS + view markup change, no migrations, no data. Revert the commit (`git revert`) on the 6 files. No DB steps, no env vars, no deploys blocked.

## Dependencies

- None external. Reuses existing `.page-head--with-action`, `.btn`, `.fab`, and `fab` Stimulus controller.

## Success Criteria

- [ ] At 768–900px width, sidebar is an off-canvas drawer (hamburger), not a top strip.
- [ ] At 768–900px width, index filters render on a 3-column grid (no staircase).
- [ ] "Nuevo X" CTA sits in the page head, aligned with the `<h1>`, on all 5 index views.
- [ ] Mobile (<640px) layout is unchanged.
- [ ] `bundle exec rspec` green; no system spec selector assumptions break.
- [ ] No visual regression on desktop (>900px).

## Proposal question round

This proposal is shaped from a complete user brief. Three product assumptions worth confirming before spec/design:

1. **Filter grid columns.** Is a fixed 3-column grid right at 768–900px, or should it be `auto-fit, minmax(180px, 1fr)` so very narrow tablets (768px) don't overflow? Default: fixed 3-col per the brief.
2. **CTA in the empty state.** The sales index renders a second "Nuevo documento" inside `.empty-state` (line 86). Should that one **also** move to the page head, or stay as the empty-state action? Default: leave the empty-state one; move only the toolbar one.
3. **`accounts_receivable` index.** It has filters but no "Nuevo" CTA. Confirm it stays out of scope (its filters will still get the grid if they share `.filters`). Default: in scope for grid, out of scope for CTA move.

Assume defaults unless corrected. No second question round requested.