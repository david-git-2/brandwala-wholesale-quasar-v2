# Sales Invoice — Product Requirements Document (PRD)

> **Module**: Sales & Multi-Channel Invoice Issuance  
> **Status**: Approved & Active  
> **Target Release**: v2.4.0  
> **Target Audience**: Desk Sales Operators, Wholesale Account Managers, Store Clerks, Cashiers, Finance Auditors

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/sales_invoice/` |
| UI | `web/src/modules/sales_invoice/`, `invoice_shared/` |
| SQL | **Split** `supabase/schemas/sales_invoice/` |
| Access | `app`; invoices owned at company |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` desk |
| In | `global_invoices`, FIFO search, collections, wholesale returns RPC. Retail/dropship may attach `recipient_profile_id` (owned by customer hub) |
| Out | Dropship packing slip; shop cart; thrift POS; Recipient as its own feature pack |

See [scopes](../../architecture/scopes.md).

---

## 1. Executive Summary

The **Sales Invoice** module handles multi-channel sales execution across B2B Wholesale credit buyers, walk-in Retail direct customers, and Dropship reseller orders.

It provides an atomic invoice creation and patching engine (`create_sales_invoice_from_payload`, `update_sales_invoice_from_payload`), strict FIFO inventory allocation, customer AR dues management, credit-backed returns with restock charges, and receipt voucher printing.

---

## 2. User Personas & Permissions

| Role | Access Level | Permitted Actions |
| :--- | :--- | :--- |
| **Desk Sales Staff** | Operational | Create draft/proforma quotes, search stock with live ATP, issue invoices, print vouchers. |
| **Cashier / Collector** | Operational | Record cash/bank collections, apply customer store credit, execute settlement write-offs. |
| **Wholesale Manager** | Operational | Approve special invoice discounts, assign customer billing profiles, issue credit returns. |
| **Tenant Admin** | Full Access | Void unpaid invoices, configure invoice print brand templates, manage billing profiles. |
| **Auditor** | Read Only | View invoice margin reports, payment allocation audit trails, and itemized return logs. |

---

## 3. User Stories & Acceptance Criteria

### US-1: Multi-Channel Invoice Creation & FIFO Stock Search
- **As a** Sales Desk Operator  
- **I want to** search warehouse products by barcode or title and view real-time Available-to-Promise (ATP) stock  
- **So that** I can generate Wholesale, Retail, or Dropship invoices without stockouts or over-selling.

#### Acceptance Criteria
- [ ] Stock search ranks allocated sister-concern stock first (Rank 0), then unallocated warehouse stock (Rank 1).
- [ ] Results within each tier are ordered strictly by oldest inbound batch first (FIFO: `created_at ASC`).
- [ ] Invoice creation is executed atomically through `create_sales_invoice_from_payload`.

### US-2: Transparent Wholesale Returns with Restock Fees
- **As a** Wholesale Manager  
- **I want to** credit returned invoice lines without rewriting historical invoiced sales quantities  
- **So that** sales audits remain immutable and return credit is accurately deducted from outstanding dues or paid excess.

#### Acceptance Criteria
- [ ] Sold `quantity` on invoice line items never changes; returns increment `return_quantity` and update net line totals.
- [ ] Restocking charges are deducted directly from the return credit on the invoice.
- [ ] Leftover paid excess becomes customer wallet store credit (`refund_method = wallet_credit`).

### US-3: Atomic Payment Collection & Settlement Write-Offs
- **As a** Cashier  
- **I want to** collect invoice dues using a combination of Cash/Bank, Customer Store Credit, and commercial settlement write-offs  
- **So that** full or partial invoice payments are recorded in a single transaction.

#### Acceptance Criteria
- [ ] Total collection satisfies: $\text{Cash} + \text{Store Credit Apply} + \text{Settlement} \le \text{Invoice Due}$.
- [ ] Cash collections credit the Tenant operating wallet; Store Credit applications debit the Customer wallet without affecting Tenant cash.
- [ ] Settlement discounts are recorded distinctly from commercial header discounts.

---

## 4. UI Layout & Wireframe

### Wholesale Invoice Creation Desk

```text
+----------------------------------------------------------------------------------------------------+
| Breadcrumbs: App > Sales > Invoices > Create Wholesale                                             |
+----------------------------------------------------------------------------------------------------+
| [ Brand: Brandwala v ]  [ Customer: ABC Traders (01700000000) v ]  [ Date: 2026-09-17 ]            |
+----------------------------------------------------------------------------------------------------+
| [ Quick Stock Search (Barcode / Name) / Bulk Paste...                                            ] |
+----------------------------------------------------------------------------------------------------+
| PRODUCT / SKU          | WAREHOUSE ATP | INVOICE QTY | UNIT SELL (BDT) | LINE DISCOUNT | LINE TOTAL|
|------------------------+---------------+-------------+-----------------+---------------+-----------|
| Denim Jacket (DJ-001)  | 45 pcs        | 10 pcs      | 1,200.00        | 0.00          | 12,000.00 |
| Cotton Polo (CP-004)   | 120 pcs       | 25 pcs      | 450.00          | 250.00        | 11,000.00 |
+----------------------------------------------------------------------------------------------------+
| NOTES & TERMS: Net 15 days credit terms              | Gross Subtotal:         23,000.00 BDT       |
|                                                      | Commercial Discount:    -1,000.00 BDT       |
|                                                      | Shipping Charge:          +500.00 BDT       |
|                                                      | NET INVOICE TOTAL:      22,500.00 BDT       |
+----------------------------------------------------------------------------------------------------+
| [ Save as Draft ]        [ Save as Proforma (PF) ]             [ SAVE & ISSUE INVOICE (Stock Out) ]|
+----------------------------------------------------------------------------------------------------+
```
