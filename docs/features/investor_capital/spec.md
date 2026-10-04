# Investor portal & capital — spec

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/investor_capital/spec.md` + [00-gaps](00-gaps.md) |
| UI | `investor_capital/`, `investor_portal/` |
| SQL | Stub `investor/`; live `investors`, `shipment_investments` in `public.sql` / procurement tables |
| Cash | [bills_pays spec](../bills_pays/spec.md) — `entity_type = investor` via `record_ledger_transaction` |
| Access | `investor` read-only portal; staff in `app` |

## Where to look

| Need | Path |
| :--- | :--- |
| Tables | Grep `investors`, `shipment_investments` in schemas |
| Portal routes | `web/src/modules/investor_portal/` |
| Staff capital | `web/src/modules/investor_capital/` |
| Ledger RPCs | Grep `record_ledger_transaction` + investor metadata |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` investor management; `investor` portal |
| In | Partner identity; staff list/detail; capital in/out; per-partner shipment table; portal summary + shipment profit |
| Out | Receipts desk; merchant payable; portal self-withdraw ([IC6](00-gaps.md)) |

Login: [tenant_auth spec](../tenant_auth/spec.md) — `role = investor` + `investor_id`.

## Target UI

| Surface | Routes |
| :--- | :--- |
| App | `/:slug/app/capital/investors`, `/:slug/app/capital/investors/:id` |
| Investor | `/:slug/investor/login`, dashboard, `/shipments` only |

## Rules

- `investors` = identity; `shipment_investments` = batch amount + `cost_share_pct`.
- Profit share = shipment gross × pct; sum of investor % ≤ 100% per shipment.
- No shadow `investor_capital_ledger`; cashbook is cash book.
- Portal v1 read-only; staff withdraw on app detail only.

## Stories

- Staff: list/add partners; detail investment in/out; edit shipment rows on partner detail.
  - [ ] Wallet RPCs on post (grep module + `public.sql`).
- Partner: dashboard + shipment list; RLS via `auth_investor_id()`; no portal withdraw.
