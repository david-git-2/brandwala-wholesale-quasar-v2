# Product-Based Costing (PBC) — Product Requirements Document (PRD)

> **Module**: Pre-Order Costing Sheets, Margin Calculation & Demand Backlog  
> **Status**: Approved & Active  
> **Target Release**: v2.4.0  
> **Target Audience**: Sourcing Managers, Procurement Officers, Wholesale Sales Desk, B2B Clients

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/product_based_costing/` |
| UI | `web/src/modules/product_based_costing/`, `costingFile/` |
| SQL | `public.sql` |
| State | Vue Query keys under the module `shared/queryKeys/` |
| Model | **Pre-order** costing. Not on-hand stock. [business models](../../architecture/business-models.md). |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` |
| In | Costing files, line formulas, backlog, demand handoff |
| Out | `global_stocks` until shipment received; shop cart |

See [scopes](../../architecture/scopes.md).

---

## 1. Executive Summary

The **Product-Based Costing (PBC)** module enables sister concerns to assemble custom pre-order quotation sheets for international merchandise, calculate dynamic unit costs and retail prices via formula-driven surcharges, and aggregate customer demand into downstream procurement workflows.

Once a quotation is confirmed by a customer group, the file transitions seamlessly into the shared Procurement Demand desk (`procuring` $\rightarrow$ `ready_for_shipment` $\rightarrow$ `delivered`), capturing unfulfilled quantities into the Customer Demand Backlog.

---

## 2. User Personas & Permissions

| Role | Access Level | Permitted Actions |
| :--- | :--- | :--- |
| **Sourcing Specialist** | Operational | Create costing files, add catalog products, customize FX exchange rates, configure item type surcharges. |
| **Wholesale Account Lead** | Operational | Set customer group markup margins, publish quotes (`offered`), lock accepted quotes (`confirmed`). |
| **Procurement Staff** | Operational | View aggregated demand on the Demand desk, log vendor PO placements, assign items to inbound shipments. |
| **Auditor / Owner** | Read Only | Audit formula markups, verify FX conversion margins, export quotation spreadsheets. |

---

## 3. User Stories & Acceptance Criteria

### US-1: Dynamic Auxiliary Costing & Markup Formula
- **As a** Sourcing Specialist  
- **I want to** apply item-type surcharges, delivery fees, and custom FX rates to overseas products (e.g. GBP $\rightarrow$ BDT)  
- **So that** accurate quoted unit prices and gross profit margins are generated automatically.

#### Acceptance Criteria
- [ ] Formula calculates: $\text{Unit Cost GBP} = \text{Web Base Price} + \text{Delivery Surcharge} + \text{Item Type Surcharge}$.
- [ ] Quoted BDT price computes: $(\text{Unit Cost GBP} \times \text{FX Rate}) \times (1 + \text{Customer Markup Rate})$.
- [ ] Line totals and profit margins update dynamically on the costing sheet.

### US-2: Shared Procurement Lifecycle & Demand Desk Alignment
- **As a** Procurement Officer  
- **I want to** manage confirmed costing files through the standard procurement lifecycle (`pending` $\rightarrow$ `offered` $\rightarrow$ `confirmed` $\rightarrow$ `procuring` $\rightarrow$ `ready_for_shipment` $\rightarrow$ `delivered`)  
- **So that** PBC pre-orders share the same operational Demand desk as catalog shop orders.

#### Acceptance Criteria
- [ ] Stays in `procuring` status through vendor PO, proforma, and inbound cargo arrival.
- [ ] Delivers fulfilled quantities from warehouse stock and issues customer invoices at `ready_for_shipment`. Vendor PO on Demand is optional when stock is already on hand (same Fulfill pick path as catalog orders).

### US-3: Automated Demand Backlog Capture
- **As a** Sourcing Lead  
- **I want to** capture shortfalls from partially delivered or out-of-stock items into the Customer Demand Backlog  
- **So that** unfulfilled demand can be pulled into future costing files with a single click.

#### Acceptance Criteria
- [ ] Upon file delivery (`delivered`), unfulfilled items ($\text{confirmed\_qty} - \text{delivered\_qty}$) automatically insert into `product_based_costing_backlog_items`.
- [ ] One-click drawer allows importing backlog items directly into new costing drafts.

---

## 4. UI Layout & Wireframe

### Costing File Details Screen

```text
+----------------------------------------------------------------------------------------------------+
| Breadcrumbs: App > Sourcing > Product-Based Costing > PBC-2026-042                                 |
+----------------------------------------------------------------------------------------------------+
| [ Workflow: Pending > Offered > [CONFIRMED] > Procuring > Ready > Delivered ]     [ Export Quote ] |
+----------------------------------------------------------------------------------------------------+
| CLIENT: Metro Mega Mart | CURRENCY: GBP (FX: 154.50) | MARKUP: 18.0% | TOTAL QUOTE: 384,200.00 BDT  |
+----------------------------------------------------------------------------------------------------+
| PRODUCT / SKU          | WEB PRICE £ | SURCHARGE £ | UNIT COST (BDT) | QUOTE PRICE | QTY | TOTAL BDT |
|------------------------+-------------+-------------+-----------------+-------------+-----+-----------|
| ASOS Trench Coat       | £ 45.00     | £ 4.50      | 7,647.75        | 9,024.00    | 20  | 180,480.00|
| Zara Slim Chino        | £ 22.00     | £ 2.00      | 3,708.00        | 4,375.00    | 30  | 131,250.00|
+----------------------------------------------------------------------------------------------------+
| [ + Add Product Items ]     [ Open Demand Backlog (4 items) ]             [ Send Quote to Client ] |
+----------------------------------------------------------------------------------------------------+
```
