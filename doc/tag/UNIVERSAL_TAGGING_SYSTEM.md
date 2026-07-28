# Universal Polymorphic Tagging System

> **Single Source of Truth** for the generalized tagging architecture across the entire Brandwala platform.

## 1. Executive Summary

Tags are a **classification** layer — labels for filtering, merchandising, CRM, and expense dimensions. They are **not** entity identity and **not** required for dropship COD, courier remittance, or middleman wallet balances.

To avoid building redundant category tables per feature, Brandwala may adopt a **Universal Polymorphic Tagging Engine** when **two or more modules** need the same controlled vocabulary.

Instead of hardcoding `product_tags` / `order_tags` tables, the architecture uses a master tag dictionary plus a generic junction that can attach a tag to any entity (products, orders, ledger rows, billing profiles, tickets).

### Status & phasing

| Phase | Scope | Status |
| :--- | :--- | :--- |
| **Now** | Dropship escrow, courier remittance, middleman wallet | **Tags out of scope** — use wallet `entity_type` + `entity_id` and order status |
| **Interim (wallet only)** | Light expense / campaign dimensions on ledger rows | Optional `metadata` jsonb on ledger — see [UNIVERSAL_WALLET_LEDGER.md](../wallet/UNIVERSAL_WALLET_LEDGER.md) |
| **Later** | Shared tags across products, orders, wallets, CRM | Build this document’s `tags` + `entity_tags` model |

### Hybrid ownership model

* **System Tags (Parent-Controlled):** Platform admin. Visible to all tenants; tenants cannot edit (e.g. logistics brand labels, VIP tier templates).
* **Custom Tags (Tenant-Controlled):** Per-tenant ops needs (e.g. `Summer-Campaign`). Visible only to that tenant.

---

## 2. Identity vs classification (locked rule)

| Job | Question | Correct tool | Tags? |
| :--- | :--- | :--- | :--- |
| **Identity** | Whose money / whose record? | `entity_type` + `entity_id` (or real FK) | **Never** |
| **Lifecycle** | Where is this order in the workflow? | Status enums / state machine | **Never** |
| **Money math** | Balance, debit, credit | Wallet / ledger | **Never** |
| **Classification** | What label / campaign / expense bucket? | Tags (or interim ledger `metadata`) | **Yes** |

**Do not** use a tag as the wallet owner, courier identity, middleman identity, or payment method. Rename/merge of tags must never break balances or FKs.

Related SSOT: [UNIVERSAL_WALLET_LEDGER.md](../wallet/UNIVERSAL_WALLET_LEDGER.md).

---

## 3. Where tags are useful (Brandwala)

### 3.1 Wallet / treasury expense dimensions (highest financial value)

Tag **ledger rows** (not wallet owners): `Marketing`, `Facebook Ads`, `Rent`, `Courier Extra`, `Eid Campaign`.

Enables: “How much did we spend on ads this month?” without a separate expense-category schema per module.

### 3.2 Shop orders / dropship ops labels

Soft staff labels: `Urgent`, `Call again`, `Fraud watch`, `VIP customer`, `Facebook lead`.

Order **status** still owns workflow (`delivered` → remitted → payout). Tags own human filters and notes.

### 3.3 Products / catalog merchandising

`Eid Sale`, `Clearance`, `New Arrival`, `Wholesale only` — promo and browse filters without proliferating hardcoded category tables.

### 3.4 Middlemen / customers (CRM-lite)

`VIP Reseller`, `Slow payer`, `High volume`, `Dhaka region` — filter and segment people. Wallet identity remains `middleman` / `customer` + real id.

### 3.5 Couriers / logistics (optional system labels)

Parent-controlled labels for filtering/reporting across orders or remittance batches when multiple couriers exist. Courier **account** remains `entity_type = 'courier'` + id.

### 3.6 Support / thrift / tickets (when those grow)

Shared vocabulary: `Damaged`, `Return`, `QC fail` across tickets, thrift lots, shipments.

---

## 4. Where **not** to use tags

| Domain | Use instead |
| :--- | :--- |
| Wallet / ledger **owner** | `entity_type` + `entity_id` |
| Order / remittance / payout **workflow** | Status enums + RPCs |
| Permissions / modules / roles | Grant system ([PERMISSION_SYSTEM.md](../PERMISSION_SYSTEM.md)) |
| Payment method (bKash, bank, cash) | `global_payment_methods` / payment rows |
| Invoice type / shipment type | Existing typed columns / enums |
| Currency, tenant, shop membership | Real FKs and scope tables |
| COD amounts, locked vs available balance | Ledger amounts + wallet state |
| Anything that must survive tag rename/delete as identity | Stable primary keys |

If removing the tag would break money correctness or access control, it was never a tag.

---

## 5. The Data Model (when built)

Exactly two tables: master dictionary + polymorphic linker.

### Table 1: `tags` (The Master List)

| Column Name | Data Type | Description |
| :--- | :--- | :--- |
| **`id`** | `uuid` (PK) | Unique ID for the tag. |
| **`tenant_id`** | `bigint` (FK) | **NULLABLE.** `NULL` = global System Tag; set = Custom Tag for that tenant. |
| **`name`** | `text` | Display name (e.g. `"Eid Sale"`, `"Urgent"`). |
| **`slug`** | `text` | URL-safe machine name. UNIQUE per `tenant_id` (system tags globally unique). |
| **`group_name`** | `text` | UI grouping (`"Marketing"`, `"CRM"`, `"Logistics"`, `"Ops"`). |
| **`parent_id`** | `uuid` (FK) | Optional hierarchy (e.g. `"Facebook Ads"` under `"Marketing"`). |
| **`color`** | `text` | Hex for UI badges. |

### Table 2: `entity_tags` (The Universal Linker)

| Column Name | Data Type | Description |
| :--- | :--- | :--- |
| **`id`** | `uuid` (PK) | Unique link ID. |
| **`tenant_id`** | `bigint` (FK) | **REQUIRED.** RLS: tenants only see tags on their entities. |
| **`tag_id`** | `uuid` (FK) | Points to `tags.id`. |
| **`entity_type`** | `text` | What is tagged (`"shop_order"`, `"product"`, `"wallet_ledger"`, `"billing_profile"`). |
| **`entity_id`** | `text` | Target id as text (UUID or BIGINT). |
| **`created_at`** | `timestamptz` | When applied. |

> **Performance:** Composite index on `(entity_type, entity_id)`; index on `(tag_id)` for “all entities with this tag”.

---

## 6. Worked example: tagging a financial expense

Admin categorizes a 50,000 TK wallet **debit** as Marketing (classification only; owner is still the tenant wallet):

1. Ensure `"Marketing"` exists in `tags`.
2. Insert `entity_tags`: `entity_type = 'wallet_ledger'`, `entity_id = <ledger row id>`.
3. P&L-by-category joins `entity_tags` to the ledger.

**Interim (before this engine ships):** store `metadata.tags` / expense keys on the ledger row only — see wallet SSOT §4. Promote to `entity_tags` when the shared dictionary is live.

---

## 7. When to build the full engine

Build `tags` + `entity_tags` when **at least two** of these are true:

- Same labels needed across products **and** orders **and** expenses
- Parent-controlled system tags used by multiple tenants
- Tag filters/reports are daily ops habits
- Tenants need their own tag dictionaries with RLS

Until then: finish wallet + remittance + dispense; use order status and wallet identity; optional ledger `metadata` for light dimensions.

---

## 8. Related docs

| Doc | Relationship |
| :--- | :--- |
| [UNIVERSAL_WALLET_LEDGER.md](../wallet/UNIVERSAL_WALLET_LEDGER.md) | Money identity + interim metadata dimensions |
| [COURIER_AND_MIDDLEMAN_FINANCIAL_MASTER_PLAN.md](../COURIER_AND_MIDDLEMAN_FINANCIAL_MASTER_PLAN.md) | Dropship escrow — tags deferred |
| [SHOP_ORDER_DROPSHIP.md](../SHOP_ORDER_DROPSHIP.md) | Dropship desk / middleman flows |
| [MASTER_PLAN.md](../MASTER_PLAN.md) | Index; tagging listed under later / optional |
