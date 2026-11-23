# TradeFlow BD — Backlog index

The [roadmap](ROADMAP.md) stays thematic. This file is the **feature-level** index—open IDs, specs, and dated fix plans.

## Open by module

| Module | Gaps file | Spec |
|--------|-----------|------|
| Bills & pays | spec.md | [atlas](features/money_bill_bridge/spec.md#atlas) · [money](features/money/spec.md) · [bills](features/bills/spec.md) |
| Procurement & stock | spec.md | [spec.md](features/procurement_stock/spec.md) |
| Shop / dropship | spec.md | [spec.md](features/shop_order/spec.md) |
| Reporting & treasury | spec.md | [spec.md](features/reporting_treasury/spec.md) |
| Products (catalog refresh UI) | [upload-and-release-visibility.md](features/products/upload-and-release-visibility.md) | [spec.md](features/products/spec.md) |
| Thrift | spec.md | [spec.md](features/thrift/spec.md) |
| Other modules | module spec | `docs/features/<name>/spec.md` |

## Active engineering plans

| Topic | Path |
|-------|------|
| Bills/pays kernel plug order (BP13+, desks) | [doc/fix/2026-10-12-bills-pays-kernel-plan.md](../doc/fix/2026-10-12-bills-pays-kernel-plan.md) |
| Bills desk URLs + kernel wrappers | [.cursor/plans/bills_desk_nav_apis_619be984.plan.md](../.cursor/plans/bills_desk_nav_apis_619be984.plan.md) |
| Supabase domain split tracker | [doc/supabase-schema.md](../doc/supabase-schema.md) |

## Conventions

- Shipped rows: delete or strike through in the module `spec.md` (see shop_order example).
- New work: add a row to the module gaps file first, then reflect the theme in [ROADMAP.md](ROADMAP.md) at quarterly review.
