# Investor Portal & Capital — PRD

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/investor_capital/` |
| UI | `web/src/modules/investor_capital/`, `investor_portal/` |
| SQL | Stub `supabase/schemas/investor/`; live `investors`, `shipment_investments` in `public.sql` / [procurement schema](../../../supabase/schemas/procurement/02_tables.sql) |
| Cash | [wallet](../wallet/01-prd.md) — `entity_type = investor` via `record_ledger_transaction` |
| Access | `investor` scope read-only portal; staff capital in `app` |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` investor management; `investor` portal (dashboard + shipments) |
| In | Partner identity; staff list/detail with capital in/out and per-partner shipment table; portal summary + shipment profit list |
| Out | Receipts / collect UI; merchant wallet; **portal** self-withdraw; **app** standalone ledger hub and shipment-first desk as primary nav (see [00-gaps](00-gaps.md) IC7) |

See [scopes](../../architecture/scopes.md). Login: [tenant_auth](../tenant_auth/01-prd.md) — membership `role = investor` + `investor_id`.

## What / who

| Role | Surface | May do |
| :--- | :--- | :--- |
| Staff | `app` | Investor list + add; open detail; record investment in / withdraw; manage shipment rows (amount, %, profit view) for that partner |
| Capital partner | `investor` | Read dashboard totals and shipment list (investment + profit); no write |
| Auditor | `app` | Same read paths as staff where grants allow |

## App scope UI (target)

```text
/:slug/app/capital/investors       List + [Add investor]
/:slug/app/capital/investors/:id   Detail hub for one partner
```

| Page | Content |
| :--- | :--- |
| List | Name, contact, active; optional summary from wallet + batches (not on profile row). Row click → detail. Add → identity dialog (+ link membership for portal). |
| Detail | Edit profile; **investment in** and **withdraw** (wallet RPCs); table of this partner’s shipments: ref, `invested_amount`, `cost_share_pct`, `computed_profit`, `profit_status`; optional compact capital history on same page |

As-built routes may still use `/capital/profiles`, `/capital/ledger`, `/capital/shipments` — converge on list + detail (IC7).

## Investor scope UI (target)

```text
/:slug/investor/login
/:slug/investor              Dashboard (wallet summary)
/:slug/investor/shipments    Shipment list: investment + profit per batch
```

Nav: **Dashboard** | **Shipments** only. No activity, profit report, or allocations pages (IC6).

## Rules (module-specific)

```text
investors              → identity only
memberships            → portal login (role investor + investor_id)
wallet (investor)      → cash in, payout, profit credit
shipment_investments   → batch amount + cost_share_pct
```

| Rule | Detail |
| :--- | :--- |
| Profit share | Shipment gross profit × `cost_share_pct`; investor % sum ≤ 100% per shipment |
| Free cash (v1) | Wallet available minus active `invested_amount` (computed) |
| No shadow ledger | No `investor_capital_ledger`; wallet is cash book |
| Portal v1 | Read-only; staff withdraw on app detail only |

## Stories

- **As staff**, I open the investor list and add a partner, **so that** I can fund batches under a clear record.
  - [ ] List shows identity; summaries are derived.
- **As staff**, I open a partner detail and post investment or withdraw, **so that** tenant cash and investor liability match.
  - [ ] Wallet RPCs on post (see [03-api-contract](03-api-contract.md)).
- **As staff**, I see and edit shipment rows on that partner’s detail, **so that** amount, share %, and profit are visible in one place.
  - [ ] Sum of % on a shipment ≤ 100%.
- **As a partner**, I use dashboard and shipment list in the investor portal, **so that** I see my totals and batch performance without editing.
  - [ ] RLS via `auth_investor_id()`; no portal withdraw.
