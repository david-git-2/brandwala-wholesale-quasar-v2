# Money spine — single reference

**Job:** One place for how money works in TradeFlow BD: layers, tables, writers, flows, balances, cases, and what is planned.

**Not:** full GL / chart of accounts / double-entry / period close / tax engine / bank reconciliation. Not product catalog.

**Live code:** `supabase/schemas/bills_pays/` · **UI:** `web/src/modules/bills_pays/` · **PR checklist:** [REFERENCE](../../kernel/REFERENCE.md) · **Tests:** [tests.md](tests.md) · `supabase/tests/golden_bills_pays_*.sql`.

---

## 1. Mental model

```text
profile  →  bill (paper)  →  bill_settlements  →  pay (cash event)  →  cashbook (where cash sat)
```

| Layer | Question | Main tables |
| :--- | :--- | :--- |
| Profile | Who is the money party? | `profiles` (`profile_type`: tenant, customer, vendor, courier, investor, …) |
| Bill | What is owed / we owe? | `bills`, `bill_lines` |
| Settlement | What reduced the bill? | `bill_settlements` (pay, credit note, custody apply) |
| Pay | What cash moved, with whom, how, why? | `pays`, `pay_instruments` |
| Cashbook | Profile ledger + physical place + on-hand pots | `cashbook_accounts`, `cashbook_points`, `cashbook_point_pots`, `cashbook_entries` |

**Profile** = money party (not `customer_groups` alone — groups are CRM; money uses `profiles.id`).

**Customer groups** do not appear on bills/pays; resolve to a billing **profile**.

Features **never** `INSERT` kernel tables. They call **SECURITY DEFINER** RPCs (`assert_kernel_money_access`).

---

## 2. Bill axes (do not mix them)

| Axis | Meaning |
| :--- | :--- |
| **Lifecycle** | `draft` → `issued` → `voided` (guarded when settlements exist) |
| **Settlement** | `unpaid` / `partial` / `settled` from sum of `bill_settlements` — not “paid” on lifecycle |

Issued bill face is **immutable**. Fix with **credit_note** / **debit_note** children (`parent_bill_id`). `reverse_pay` only moves settlement.

**Direction (who owes whom):** derived from `from_profile_id` / `to_profile_id` — tenant on `from` = they owe (AR); tenant on `to` = we owe (AP). Do not rely on `invoice_type` alone.

**Settlement kind (stock AR):** `take` = sales at issue; `condition` = sales when paid. AP / fee bills: null.

---

## 3. Cashbook (profile spine)

| Piece | Rule |
| :--- | :--- |
| **Account** | One `cashbook_accounts` row per **`profiles.id`** per books tenant + currency (`profile_id`). Balances: **`available_balance`**, **`pending_balance`**, **`locked_balance`** only. Legacy `entity_type` / `entity_id` remain for compat. |
| **Class** | Tenant mirror profile → `tenant_asset`; other profile types → `profile_custody`. |
| **Point** | Named **place** under an account (`code`, `name`, `is_active`). No currency, kind, custodian, or sort on the point — staff label places freely. |
| **Pot** | On-hand cash per point × currency (`cashbook_point_pots`). |
| **Defaults** | Each account: cash point **`office`** + **BDT** pot; ids on `default_cashbook_point_id` / `default_cashbook_point_pot_id`. |
| **Provision** | `ensure_cashbook_account_for_profile` (on `upsert_profile_for_party`, writers, backfill). SQL: `20_cashbook_profile_spine.sql` · migrations `20261110214000`, `20261110215000`. |

**Pays:** `cashbook_point_id` is the physical place cash moved through — usually a point on the **tenant mirror** cashbook; profile cashbooks carry defaults for structure and future auto-routing.

**Staff UI:** Cashbook desk lists points/pots per party account; pay in/out picks a pot under an active point.

---

## 4. One pay, two legs (live)

Every money movement is **one `pays` row** with **two profile endpoints**:

| Column | Meaning |
| :--- | :--- |
| `from_profile_id` | Who the money leaves (payer side) |
| `to_profile_id` | Who the money arrives at (payee side) |
| `description` | Short human label (defaults from `note` when writers omit it) |
| `profile_id` | Legacy counterparty anchor — keep for older reads; prefer `from`/`to` for direction |

| Leg | Where stored |
| :--- | :--- |
| How | `pay_instruments` (cash, bank, bKash, …) |
| Why | `note`, `reference`; **purpose** via `source` today → `purpose_code` + `money_purposes` ([BP27](#gaps-open)) |
| What for | `source_type` / `source_id` on pays (partial) |
| No profile pay | `counterparty_name` when purpose allows none (planned) |

`pays.tenant_id` is **books scope only** — not a semantic “from” party.

**Activity reads:** `get_payment_profile_for_staff` / `list_profile_activity_for_staff` match pays where the party’s profile is **`from_profile_id` OR `to_profile_id`** (falls back to `profile_id` when endpoints are null on old rows).

**Idempotency:** `pays.idempotency_key` per tenant — duplicate POST returns same pay.

### Tenant mirror + default sink profiles

Each **books tenant** (root `tenants.id`) gets:

| Profile | `profile_type` | `subject_id` | Name |
| :--- | :--- | :--- | :--- |
| Tenant mirror | `tenant` | books tenant id | tenant name (trigger) |
| Default income | `company` | `-900001` | Default income |
| Default expense | `company` | `-900002` | Default expense |

IDs in `tenants.preference`: `default_income_profile_id`, `default_expense_profile_id`. `ensure_tenant_default_money_profiles(books_id)` on root tenant create and tenant profile sync.

**Default endpoints** when UI omits ids — `_kernel_resolve_pay_profile_endpoints`:

| `pays.source` (typical) | `from` | `to` |
| :--- | :--- | :--- |
| `ap_payout` | tenant mirror → else default expense | counterparty (vendor) |
| `customer_cash`, `bank`, `store_credit`, `courier_remittance`, `deposit` | counterparty | tenant mirror → else default income |
| other | counterparty → default income | tenant mirror → default expense |

Writers **`post_ap_payout_with_allocations`** and **`post_customer_receipt_with_allocations`** accept optional `p_from_profile_id`, `p_to_profile_id`, `p_description`. SQL: `19_tenant_default_money_profiles.sql`.

---

## 5. Writers (only these change money)

| RPC | Job |
| :--- | :--- |
| `upsert_draft_bill` / `issue_bill` / `void_bill` | Paper + lines + `source_*` plug |
| `create_bill_adjustment` / `issue_bill_adjustment` | CN/DN child |
| `post_money_in` / `post_money_out` | Generic in/out + optional alloc + cashbook |
| `post_customer_receipt_with_allocations` | Customer collect / remittance; `from`/`to`/`description` |
| `post_ap_payout_with_allocations` | Vendor AP payout; `from`/`to`/`description` |
| `ensure_tenant_default_money_profiles` | Default income/expense + `preference` ids |
| `ensure_cashbook_account_for_profile` | Profile cashbook + office point + BDT pot |
| `_kernel_post_commission_payout` | Dropship merchant profit (via `post_money_out`) |
| `apply_settlement_to_bill` | Custody or open CN → another bill |
| `reverse_pay` | Unwind pay; bill stays issued |
| `transfer_cashbook_point` | Move cash between points (same currency v1) |

No new per-feature payout RPCs — use `source_type` + generic writers ([BP24](#gaps-open) shipped).

**Reads:** grep `supabase/schemas/bills_pays/09_kernel_reads.sql` (`get_bill_net_balances`, `v_kernel_bill_summaries`, `list_profile_activity_for_staff`, …).

---

## 6. Pays `source` (live) and product cases

| `pays.source` (live) | Typical flow | Tenant direction |
| :--- | :--- | :--- |
| `customer_cash` | Customer pays bill | in |
| `bank` | Bank collect | in |
| `store_credit` | Store credit | in |
| `courier_remittance` | Dropship remittance | in |
| `ap_payout` | Pay vendor AP | out |
| `commission` | Pay merchant profit / draw custody | out |
| `deposit` / `owner_withdraw` | Tenant till (partial writers) | in / out |

**Target:** `money_purposes` registry ([BP27–BP29](#gaps-open)) extends the above with expense, advance, courier_payout, vendor_refund, capital, salary, etc. Writers validate via `_kernel_assert_purpose` (direction, party rule, custody effect).

| Who | Case (target) | Effect (summary) |
| :--- | :--- | :--- |
| Tenant | Deposit / withdraw / expense pay | tenant cash ±; expense → bill + pay out |
| Customer | Pay bill / advance / profit withdraw | AR down; overpay → custody |
| Curia / vendor / investor | Remittance, AP, refund, capital | As today + planned purposes in gaps |

Vendor **credit** = credit note on `bills`, not a pay. Full case matrix lived here historically — keep product nuance in module specs when adding a flow.

---

## 7. Balances (what staff see)

| View | Source |
| :--- | :--- |
| **Has with us** (custody) | `cashbook_accounts` where `profile_id` = party (`profile_custody`) |
| **They owe / we owe** | open bills (`v_kernel_bill_summaries`, `list_open_on_profile`) |
| **Tenant cash** | tenant mirror account (`tenant_asset`) + points/pots / header `available_balance` |

Overpay on collect → **custody credit**. Pay out above custody → **blocked**. Apply via pay alloc or `apply_settlement_to_bill`.

---

## 8. Pay flows (summary)

| Flow | Alloc to bills? | Overflow |
| :--- | :--- | :--- |
| Customer collect | yes → AR | profile custody |
| Courier remittance | yes → merchant AR | merchant custody |
| AP payout | yes → AP | vendor custody (if any) |
| Merchant profit | no | draws custody |
| Tenant deposit / owner withdraw | no | till only |
| Expense pay | yes → expense bill | no |

Dropship: **COD face ≠ sales**; remittance = net bank in. Shipment AP: one **issued** bill per **bucket × currency**; pay ties to `cashbook_point_id`. See [procurement money-kernel-wiring.md](../procurement_stock/money-kernel-wiring.md) and [§Worked examples](#worked-examples).

---

## 9. Adapter plug (bills)

| Feature | `source_type` | `source_key` (examples) |
| :--- | :--- | :--- |
| POS / manual | `compose` | — |
| Dropship order | `shop_order` | merchant bill / courier AP |
| Shipment AP | `shipment_cost` | `material:USD`, `freight:GBP` |
| Commission payout | `commission` | order id |
| Delivery close | `delivery_close` | paper id |

Discovery: `list_bills_for_source(tenant, source_type, source_id)`. No feature FK to `bills` for new work ([BP9](#gaps-open)).

---

## 10. App (as-built)

| Desk | Path | Grant |
| :--- | :--- | :--- |
| Bills | `/:slug/app/bills` (+ `/create`, `/:billId`) | `global_invoice` |
| Payments | `/:slug/app/finance/payments` | `payments` |
| Cashbook | `/:slug/app/cashbook` | `cashbook` |
| People (target) | `/:slug/app/people` | [BP26–BP31](#gaps-open) |

Module root: `web/src/modules/bills_pays/`. Legacy `/app/sales/invoices/*` → `/app/bills/*`. List: `list_bills_desk_page`; detail: `get_bill_detail_bundle`.

### Rename map (spec term → live)

| Spec | Live | Notes |
| :--- | :--- | :--- |
| `bills` / `bill_lines` | same | was `sales_invoices` / items; children FK often `invoice_id` |
| `pays` / `pay_allocations` / `pay_instruments` | same | was `global_payments` |
| `cashbook_*` | same | was `wallet_*` / `universal_wallet_ledger` |

---

## 11. Gaps {#gaps-open}

### Open (money movements — not fully live)

| ID | Target | Today | Next |
| :--- | :--- | :--- | :--- |
| BP26 | Two-sided activity + People UI | Pays `from`/`to` on main writers; activity lists either leg | Other writers; panel polish |
| BP27 | `money_purposes` + pay/bill `purpose_code` | Registry + columns + assert helper | Writers pass purpose params |
| BP28 | `deposit`, `owner_withdraw`, expense bills | Partial writers | Tenant panel UI |
| BP29 | `advance`, `courier_payout`, `vendor_refund` | Partial | Seed + writers |
| BP30 | Investor on `pays` | Ledger only | `capital_in` / `capital_out` |
| BP31 | `staff` profile type | — | Enum; payroll later |

Kernel track (BP1–BP25, …): **shipped** — [tests.md](tests.md). Cosmetic: legacy wallet index names, `/app/wallet` redirect.

---

## 12. Key schema (grep `02_tables.sql` for DDL)

| Table | Keys |
| :--- | :--- |
| `bills` | `from_profile_id`, `to_profile_id`, `profile_id`, `source_*`, `settlement_kind`, `document_kind`, `parent_bill_id`, `purpose_code` (planned) |
| `pays` | `from_profile_id`, `to_profile_id`, `description`, `profile_id`, `source`, `amount`, `unallocated_amount`, `cashbook_point_id`, purpose/source columns (partial) |
| `cashbook_accounts` | `profile_id`, three balances, `default_cashbook_point_id`, `default_cashbook_point_pot_id`, `account_class`, legacy `entity_*` |
| `cashbook_points` | `cashbook_account_id`, `tenant_id`, `code`, `name`, `is_active` |
| `cashbook_point_pots` | `cashbook_point_id`, `currency_code`, pot balances |
| `cashbook_entries` | `type` credit/debit, `amount`, `cashbook_point_id`, `source_type`, `source_id` |

**Concurrency (writers):** shipment advisory lock; bills/pots `FOR UPDATE` in ascending id order; pots updated only via trigger on `cashbook_entries`; `pays.idempotency_key` unique per tenant.

---

## 13. Worked examples {#worked-examples}

Same SKU. Shipment cost on **shipment**; GP = [reporting_treasury spec](../reporting_treasury/spec.md).

| Step | Wholesale | Dropship |
| :--- | :--- | :--- |
| Pay in | Collect full amount | Remittance after delivered — **net bank in**, not COD |
| Leftover | Customer custody | Dropshipper custody, then pay out |

**Wholesale:** Sell 1,500; pay 1,500 → bill paid. Overpay 2,000 → alloc 1,500 + custody +500.

**Dropship:** Invoice 1,500; COD 2,200; remittance 2,120 → alloc 1,500 + merchant custody ~620; pay out 620 later.

**Shipment AP:** Vendor + freight + local → one pay out with alloc; after issue, commercial fix = credit note only.

**Do not:** treat COD as sales; post tenant cash on deliver; second pay product for dropship (same `pays`, different `source`).

---

## 14. Related

| Module | Doc |
| :--- | :--- |
| Customer | [customer/spec.md](../customer/spec.md) |
| Shop / dropship | [shop_order/spec.md](../shop_order/spec.md) |
| Shipment AP | [procurement money-kernel-wiring.md](../procurement_stock/money-kernel-wiring.md) |
| Reports / investors | [reporting_treasury/spec.md](../reporting_treasury/spec.md), [investor_capital/spec.md](../investor_capital/spec.md) |

Model: BW — [business-models](../../architecture/business-models.md).
