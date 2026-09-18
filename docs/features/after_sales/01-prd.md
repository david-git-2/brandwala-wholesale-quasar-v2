# After-Sales & Returns — Product Requirements Document (PRD)

> **Module**: Returns Hub, Warranty, DOA Replacements & Case Management (RMA)  
> **Status**: Approved & Active  
> **Target Release**: v2.4.0  
> **Target Audience**: Customer Support Staff, Warehouse Inspection Teams, Wholesale Account Managers, Resellers

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/after_sales/` |
| UI | `web/src/modules/after_sales/` |
| SQL | Invoice + shop_order RPCs (`process_wholesale_invoice_return`, `finalize_dropship_return`) |
| State | Follow files in the module |
| Access | `app` scope; `effectiveGrants` |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` (policies, cases, intake) |
| In | RMA cases, return policy, wholesale + dropship return execution |
| Out | Creating original invoices; warehouse bin layout |

See [scopes](../../architecture/scopes.md).

---

## 1. Executive Summary

The **After-Sales & Returns** module provides a centralized governance layer, parent-configurable policies, customer RMA case management, and inspection workflows across Wholesale B2B and Dropship channels.

It coordinates return-for-credit, DOA swap, replacement, and repair outcomes by interfacing directly with underlying domain execution engines (`process_wholesale_invoice_return`, `finalize_dropship_return`) while strictly preserving inventory and financial ledger invariants.

---

## 2. User Personas & Permissions

| Role | Access Level | Permitted Actions |
| :--- | :--- | :--- |
| **Support / Operations Staff** | Operational | Log external dropship complaints, open RMA cases, receive physical goods, execute approved outcomes. |
| **Warehouse Inspector** | Operational | Inspect arrived items, document condition, select outcome routing (`credit`, `replace`, `repair`, `reject`). |
| **Sales Manager** | Managerial | Approve high-value RMA claims exceeding policy thresholds, grant fee waivers. |
| **Parent Tenant Admin** | Full Access | Configure return policy windows, set restocking fee schedules, override case rules. |

---

## 3. User Stories & Acceptance Criteria

### US-1: Centralized Returns Hub
- **As an** Operations Support Agent  
- **I want to** view and manage all after-sales cases across Wholesale and Dropship in a unified Returns Hub (`/app/after-sales`)  
- **So that** customer return requests, incoming parcels, and warranty claims are tracked in one place.

#### Acceptance Criteria
- [ ] Returns Hub displays tabs for All Cases, Awaiting Receipt, Inspecting, and Completed.
- [ ] Supports both Wholesale B2B claims (linked to `sales_invoices`) and Dropship complaints (linked to `shop_orders`).

### US-2: Parent Policy Programs & Rules
- **As a** Parent Business Owner  
- **I want to** define return windows and restocking fee formulas for 4 standard programs (`return_credit`, `doa`, `replacement`, `warranty`)  
- **So that** returns are handled consistently according to commercial guidelines.

#### Acceptance Criteria
- [ ] Policy rules are snapshot immutably on each RMA case at the time of case creation.
- [ ] DOA (Dead on Arrival) and Replacement claims automatically waive restocking charges ($0$ fee).

### US-3: Physical Inspection & Outcome Routing
- **As a** Warehouse Inspector  
- **I want to** log received returned items and route them to Credit, Replacement, Repair, or Rejection  
- **So that** stock movements and financial credits are executed accurately based on physical condition.

#### Acceptance Criteria
- [ ] Returned sellable or held inventory is posted via `return_inbound` stock movements.
- [ ] Credit execution reduces invoice dues first, crediting customer store credit only if the invoice was previously overpaid.

---

## 4. UI Layout & Wireframe

### Returns Hub Desk

```text
+----------------------------------------------------------------------------------------------------+
| Breadcrumbs: App > Operations > Returns Hub                                                        |
+----------------------------------------------------------------------------------------------------+
| [ Search RMA #, Customer, Order... ] [ Filter: Channel v ] [ Program v ]       [ + Open New Case ] |
+----------------------------------------------------------------------------------------------------+
| RMA #        | CHANNEL   | CUSTOMER / RECIPIENT | PROGRAM       | STATUS      | OUTCOME   | ACTION |
|--------------+-----------+----------------------+---------------+-------------+-----------+--------|
| RMA-WS-00101 | Wholesale | Metro Mega Mart      | Return Credit | Inspecting  | Credit    | [View] |
| RMA-DS-00102 | Dropship  | Karim (Reseller DS)  | DOA           | Awaiting Rx | Replace   | [View] |
| RMA-WS-00103 | Wholesale | Apex Retailers       | Warranty      | In Repair   | Repair    | [View] |
+----------------------------------------------------------------------------------------------------+
| Pagination: Showing 1 - 20 of 64 Active Cases                                                      |
+----------------------------------------------------------------------------------------------------+
```
