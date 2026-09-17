# Universal Wallet & Ledger — Product Requirements Document (PRD)

> **Module**: Universal Multi-Currency Financial Ledger & Entity Wallets  
> **Status**: Approved & Active  
> **Target Release**: v2.4.0  
> **Target Audience**: Treasury Accountants, Finance Directors, Storefront Resellers, Cashiers, Operational Staff

---

## 1. Executive Summary

The **Universal Wallet & Ledger** module provides a centralized, append-only, double-entry financial ledger across all business counterparties (Tenants, Vendors, Couriers, Merchants/Customers, Cargo Companies, and Investors).

It enforces the **Parent Books Rule** (all financial accounts and ledgers are consolidated under the Parent Tenant books with `operating_tenant_id` tracking operational desks) and eliminates fragmented sub-ledgers.

---

## 2. User Personas & Permissions

| Role | Access Level | Permitted Actions |
| :--- | :--- | :--- |
| **Finance Director / Owner** | Full Access | View company cash positions, audit parent books, perform manual ledger adjustments, execute inter-wallet transfers. |
| **Treasury Cashier** | Operational | Record cash deposits/payouts, reconcile bank remittances, post courier settlements. |
| **Storefront Reseller** | External Portal | View earnings statement on merchant wallet, submit cash withdrawal requests. |
| **Auditor** | Read Only | View immutable ledger audit trails, inspect reverse transaction logs, verify running balances. |

---

## 3. User Stories & Acceptance Criteria

### US-1: One Consolidated Wallet Per Business Counterparty
- **As a** Finance Manager  
- **I want to** maintain exactly one balance and ledger account per entity (`parent_tenant_id`, `entity_type`, `entity_id`, `currency_code`)  
- **So that** customer store credit, vendor payables, courier COD, and tenant operating cash are never mixed or fragmented.

#### Acceptance Criteria
- [ ] Ledger lines are permanent and append-only (`universal_wallet_ledger` rows are never deleted).
- [ ] Running balances are calculated deterministically via `record_ledger_transaction`.
- [ ] Adjustments are recorded as explicit reversing transactions (`reverse_wallet_ledger_entry_for_staff`).

### US-2: Parent Books Consolidation & Sister Concern Attribution
- **As an** Accountant  
- **I want to** attribute transactions to the parent books (`parent_tenant_id`) while preserving the child operational desk (`operating_tenant_id`)  
- **So that** consolidated financial reports and child-level drill-downs are always consistent.

#### Acceptance Criteria
- [ ] Operating cash (`entity_type = 'tenant'`) is pooled at `entity_id = parent_tenant_id`.
- [ ] UI lists and RPCs resolve the parent books ID using `resolve_parent_tenant_id(p_tenant_id)`.

### US-3: Storefront Merchant Margin Payouts
- **As a** Dropship Reseller  
- **I want to** view my credited profit statement and withdraw available funds  
- **So that** earnings from delivered orders can be deposited directly to my bank or mobile wallet.

#### Acceptance Criteria
- [ ] Delivered dropship orders credit profit spread to the merchant wallet.
- [ ] Cash payouts debit the merchant wallet and tenant cash pool via `dispense_middleman_payout_from_tenant`.

---

## 4. UI Layout & Wireframe

### Universal Wallet Directory & Detail

```text
+----------------------------------------------------------------------------------------------------+
| Breadcrumbs: App > Finance > Universal Wallets > Customers                                         |
+----------------------------------------------------------------------------------------------------+
| [ Filter: All Entities v ] [ Search entity name... ]            [ + Record Manual Transaction ]    |
+----------------------------------------------------------------------------------------------------+
| ENTITY NAME            | TYPE       | CURRENCY | CURRENT BALANCE | UNSETTLED / PENDING | LAST ACTIVE |
|------------------------+------------+----------+-----------------+---------------------+-------------|
| ABC Traders (Dhanmondi)| Customer   | BDT      | 45,000.00 BDT   | 0.00 BDT            | Today 14:20 |
| Steadfast Logistics    | Courier    | BDT      | 124,500.00 BDT  | 18,200.00 BDT       | Today 11:05 |
| Guangzhou Direct       | Vendor     | CNY      | 24,000.00 CNY   | 0.00 CNY            | Yesterday   |
+----------------------------------------------------------------------------------------------------+
| LEDGER AUDIT TRAIL (ABC Traders)                                                                   |
| - 2026-09-17: Credit (+5,000 BDT) | Overpayment Refund from INV-WS-001 | Bal After: 45,000 BDT      |
| - 2026-09-15: Debit  (-10,000 BDT)| Store Credit Applied to INV-WS-004 | Bal After: 40,000 BDT      |
+----------------------------------------------------------------------------------------------------+
```
