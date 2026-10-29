# TradeFlow BD — Product Roadmap

Vision: One multi-tenant platform where wholesale, shop, and pre-order teams run stock, bills, pays, and reports from a single money kernel—without duplicate ledgers or mixed business models.

Last updated: 2026-10-29 · Owner: Product + engineering

## Goals

| ID | Goal | Success looks like |
|----|------|--------------------|
| G1 | **Unified money kernel** | Every BW cash and paper event flows through `bills` → `bill_settlements` → `pays` → `cashbook`; features plug in via RPCs, not shadow tables |
| G2 | **Trustworthy ops chain** | Inbound shipment → landed cost → sell (wholesale / shop / dropship) → after-sales with P&L that matches procurement rules |
| G3 | **Clear channels, one tenant** | BW, pre-order, K-beauty, and thrift stay on their own stock/money paths; dropship remittance and COD reconcile to kernel balances |
| G4 | **Staff-ready surfaces** | App desks (bills, payments, cashbook, procurement, shop) match specs, grants, and reporting definitions (sales vs cash vs COD) |

## 🟢 NOW — Shipped

Theme: **Money kernel spine** — serves **G1**, **G3**

| Item | Area | Status |
|------|------|--------|
| Kernel phases 1–5 (BP2–BP25, settlements-first, golden tests) | Backend / `bills_pays` | ✅ Shipped |
| Cashbook module grant + staff RPCs (`cashbook`, account class balances) | Backend + nav | ✅ Shipped (backend **1.0.28**) |
| Dropship remittance + shipment AP FX golden scenarios | Backend + shop_order | ✅ Shipped |
| Pay / reverse / cheque bounce / point transfer | Backend | ✅ Shipped |
| Shop order finance wiring (remittance, delivery close, recipient gate) | shop_order | ✅ Shipped |

Outcome delivered: BW money is kernel-backed in production—bills, settlements, pays, and cashbook pots with pgTAP + CI golden coverage — v1 live **Oct 2026**.

Also shipped (v1):

- Profile-only money parties (BP3); `/app/cashbook` route with legacy wallet redirect
- Shipment AP sync on money kernel (WA15); procurement cost-entry AP cleanup (PS12)
- Declarative schema splits started (`procurement/`, `shop_order/`, `notifications/`, `bills_pays/`)
- Dashboard stub badges removed (DA2)

## 🟡 NEXT — Planned & in progress

### In progress — serves **G1**, **G4** · Q4 2026

Theme: **Bills desk polish** (URLs, API boundary, fetch discipline)

| Item | Description | Target |
|------|-------------|--------|
| Desk wrapper RPCs | `update_draft_bill`, `issue_wholesale_bill`, `issue_retail_bill` — no edits to frozen money spine | Q4 2026 |
| Route tree | `/app/bills/*` with redirects from legacy sales/invoice paths | Q4 2026 |
| `billsRepository` | Desk calls kernel + wrappers only; store-first profiles/currency | Q4 2026 |
| `bills-desk.md` | Per-page API contract for agents and QA | Q4 2026 |

Outcome targeted: Staff and deep links say “bill” everywhere; the web layer never calls legacy invoice RPC names directly.

### Planned — serves **G1**, **G4** · Q4 2026 – Q1 2027

Theme: **Modular money desks** (compose + pay product track)

| Item | Description | Target |
|------|-------------|--------|
| BP13 — modular compose | Any paper (AR/AP); stock optional; header-only lines | Q1 2027 |
| BP14 — modular pay | One receive/pay-out flow from instruments or cashbook; optional bill alloc | Q1 2027 |
| Note desk (BP8) | Credit/debit notes + open-credit pay on bill detail | Q1 2027 |
| Leftover apply UI (BP11) | Apply profile leftover / open credit to bills from pay desk | Q1 2027 |

Outcome targeted: Finance staff issue and settle all common paper without stock-only compose or split pay products.

### Planned — serves **G2**, **G4** · Q1 2027

Theme: **Procurement & shipment truth**

| Item | Description | Target |
|------|-------------|--------|
| PS7–PS8 | Vendor credits vs profit; non-capitalizable costs in landed math | Q1 2027 |
| PS13–PS14 | Full bucket landed stamp; one AP bill per bucket × currency | Q1 2027 |
| PS10 | Shipment close guard + read-only UI when closed | Q1 2027 |
| RT18–RT19 | Shipment P&L minus non-capitalizable rows; GP aligned to landed + local | Q1 2027 |

Outcome targeted: Shipment summary, AP bills, and treasury reports tell the same COGS story.

### Planned — serves **G4** · Q1 2027

Theme: **Catalog ops visibility**

| Item | Description | Target |
|------|-------------|--------|
| Catalog refresh UI | Staff view scrape/upload log + backend/frontend release versions (backend writers exist) | Q1 2027 |

Outcome targeted: Catalog admins see last sync and deploy versions without SSH or Makefile.

## 🔵 LATER — Exploring

Theme: **Platform depth & retirement** — serves **G2**, **G3**

| Item | Description |
|------|-------------|
| PS9 | Retire `global_stock_allocations`; shop/procurement sell from `global_stock_id` / listings |
| Schema split | Expand declarative domains out of `public.sql` (see [split tracker](../doc/supabase-schema.md)) |
| Kernel cosmetics | Rename legacy `universal_wallet_*` constraints; dropship `wallet_*` metadata strings |
| B7 legacy cutover | Tenant cutover chain — drop pre-kernel invoice paths when grep shows zero callers |
| Thrift TH3 | Hang-tag PDF voucher or drop from PRD |
| Money out of scope | Full GL, aging suites, cheque lifecycle beyond bounce, note attachments |

Outcome targeted: Less legacy surface area and clearer module boundaries—not committed dates.

## At-a-glance

| Horizon | Theme | Goal | Timing | Confidence |
|---------|-------|------|--------|------------|
| Now | Money kernel + shop finance wiring | G1, G3 | Shipped (Oct 2026) | ✅ Done |
| Next | Bills desk polish | G1, G4 | Q4 2026 | Medium (in progress) |
| Next | Modular compose / pay / notes | G1, G4 | Q1 2027 | High |
| Next | Procurement P&L + reporting alignment | G2, G4 | Q1 2027 | Medium |
| Next | Catalog refresh UI | G4 | Q1 2027 | High |
| Later | Allocations retirement + schema split | G2, G3 | 2027+ | Low |

Living document — reviewed each quarter. Feature-level IDs and fix steps live in [BACKLOG.md](BACKLOG.md), not here.

| Need | Document |
|------|----------|
| Module unfinished rows | Each `docs/features/<module>/00-gaps.md` |
| Money build order (engineers) | [doc/fix/2026-10-12-bills-pays-kernel-plan.md](../doc/fix/2026-10-12-bills-pays-kernel-plan.md) |
| Bills desk execution plan | [.cursor/plans/bills_desk_nav_apis_619be984.plan.md](../.cursor/plans/bills_desk_nav_apis_619be984.plan.md) |
| Money target map | [features/bills_pays/README.md](features/bills_pays/README.md) |
| How to sell (BW / pre-order / Koba / thrift) | [architecture/business-models.md](architecture/business-models.md) |
| Doc index | [README.md](README.md) |
