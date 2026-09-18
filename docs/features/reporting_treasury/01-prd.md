# Reporting & Treasury — Product Requirements Document (PRD)

> **Module**: Treasury Analytics, Financial Reports & Cash Settlement  
> **Status**: Approved & Active  
> **Target Release**: v2.4.0  
> **Target Audience**: Business Owners, CFOs, Financial Auditors, Treasury Controllers, Operational Staff

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/reporting_treasury/` |
| UI | `web/src/modules/reporting_treasury/` |
| SQL | `public.sql` |
| Access | `app`; parent books |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` |
| In | Eight finance reports, payments allocation |
| Out | Operational edit of shipments/invoices (read-side) |

See [scopes](../../architecture/scopes.md).

---

## 1. Executive Summary

The **Reporting & Treasury** module delivers parent-level financial visibility, read-side profit & loss derivation, customer accounts receivable (AR) aging schedules, shipment batch profitability, and unified cash collection reconciliation.

It operates without shadow accounting ledgers by dynamically computing realized margins from locked operational records (`sales_invoice_items.unit_cost_price`, `global_shipments.landed_cost_total_bdt`) and reconciling liquid cash inflow.

---

## 2. User Personas & Permissions

| Role | Access Level | Permitted Actions |
| :--- | :--- | :--- |
| **Owner / CFO** | Full Access | View executive month snapshots, gross profit breakdowns, shipment P&L shrinkage, and cash drawer balances. |
| **Treasury Controller** | Operational | Monitor customer dues aging, record bulk AR payments across invoices, verify courier COD settlements. |
| **Auditor** | Read Only | Audit invoice margins, inspect historical exchange rates, verify shipment cost apportionments, export CSV reports. |

---

## 3. User Stories & Acceptance Criteria

### US-1: Dynamic Margin & Profit Derivation (No Shadow Ledgers)
- **As a** Finance Manager  
- **I want to** audit gross profit margins per invoice line and per shipment batch  
- **So that** profitability is computed directly from true landed unit costs and historical invoice sales snapshots.

#### Acceptance Criteria
- [ ] Invoice margin report (`list_invoice_margin_report`) uses `sales_invoice_items.unit_cost_price` snapshot taken at issue time.
- [ ] Shipment P&L report (`get_tenant_shipment_profit_report`) calculates realized revenue, gross profit, and unsold inventory valuation.

### US-2: 8 Standard Financial & Operational Reports
- **As an** Operations Lead  
- **I want to** access 8 standardized treasury reports  
- **So that** operational and financial health can be monitored from dedicated views.

#### Acceptance Criteria
- [ ] **1. Cash In Report** (`get_tenant_cash_in_report`): Till view of incoming cash/bank credits with method breakdown.
- [ ] **2. Customer Dues Report** (`get_customer_dues_report`): Real-time outstanding customer balances, aging, and credit limits.
- [ ] **3. Invoice Book** (`get_tenant_invoice_book_report`): Chronological register of issued sales invoices.
- [ ] **4. Invoice Profit Report** (`get_tenant_invoice_profit_report`): Net sales vs cost of goods sold after credit returns.
- [ ] **5. Shipment Profit Report** (`get_tenant_shipment_profit_report`): Batch landed cost vs realized revenue vs unsold stock.
- [ ] **6. Wallet Liability Report** (`get_tenant_wallet_liability_report`): Outstanding customer store credits and payables.
- [ ] **7. Courier COD Report** (`get_tenant_courier_cod_report`): Delivered COD collections vs bank remittances.
- [ ] **8. Month Snapshot Report** (`get_tenant_month_snapshot_report`): Executive one-page KPI summary.

### US-3: Multi-Invoice AR Payment Allocation
- **As a** Treasury Officer  
- **I want to** record a single customer bank deposit and allocate it across multiple open invoices  
- **So that** customer receivables are cleared systematically.

#### Acceptance Criteria
- [ ] Invoking `create_billing_profile_payment_with_allocations` atomically creates payment records, updates invoice dues, and credits tenant liquid cash.

---

## 4. UI Layout & Wireframe

### Executive Treasury Dashboard & Reports Hub

```text
+----------------------------------------------------------------------------------------------------+
| Breadcrumbs: App > Finance > Treasury & Reports                                                    |
+----------------------------------------------------------------------------------------------------+
| [ Date Range: This Month v ] [ Tenant Scope: Parent Books v ]                       [ Export CSV ] |
+----------------------------------------------------------------------------------------------------+
| KPI CARDS:                                                                                         |
| [ TOTAL REVENUE: 4.85M BDT ] [ GROSS PROFIT: 1.12M BDT ] [ CASH IN: 3.40M BDT ] [ AR DUE: 890K BDT]|
+----------------------------------------------------------------------------------------------------+
| REPORTS HUB:                                                                                       |
| [ 1. Cash In Till ]      [ 2. Customer Dues ]     [ 3. Invoice Book ]     [ 4. Invoice Profit ]    |
| [ 5. Shipment Batch P&L] [ 6. Wallet Liability ]  [ 7. Courier COD ]      [ 8. Month Snapshot ]    |
+----------------------------------------------------------------------------------------------------+
| INVOICE MARGIN AUDIT TABLE                                                                         |
| INVOICE #    | CUSTOMER      | NET REVENUE   | COGS (COST)   | GROSS PROFIT  | MARGIN % | DUE BDT  |
|--------------+---------------+---------------+---------------+---------------+----------+----------|
| INV-WS-001   | Metro Mart    | 145,000 BDT   | 102,000 BDT   | 43,000 BDT    | 29.6%    | 0.00 BDT |
| INV-WS-002   | Apex Retail   | 88,500 BDT    | 61,000 BDT    | 27,500 BDT    | 31.0%    | 38.5k BDT|
+----------------------------------------------------------------------------------------------------+
```
