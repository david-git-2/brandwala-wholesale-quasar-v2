# Procurement & Stock — Product Requirements Document (PRD)

> **Module**: Procurement & Inbound Stock Management  
> **Status**: Approved & Active  
> **Target Release**: v2.4.0  
> **Target Audience**: Procurement Staff, Warehouse Managers, Operations Admins, Auditors

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/procurement_stock/` |
| UI | `web/src/modules/procurement_stock/`, `vendor/` |
| SQL | **Split** `supabase/schemas/procurement/` (`01_types` … `04_rls`) |
| State | Mix of Pinia and Vue Query — copy neighbors |
| Model | **BW** warehouse. See [business models](../../architecture/business-models.md). |
| Access | `app`; parent owns stock |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` only |
| In | Shipments, landed cost, bins, `global_stocks`, movements, vendors, allocations, batch code analyze |
| Out | Shop cart, Koba, thrift boxes, PBC quote formulas, product catalog `batch_code_manufacture_date` |

See [scopes](../../architecture/scopes.md).

---

## 1. Executive Summary

The **Procurement & Stock** module manages end-to-end inbound international logistics, supplier purchase orders, customs clearance charges, freight cargo apportioning, multi-tier warehouse bin inventory, and virtual stock allocations to sister concerns (child tenants).

Physical stock is owned strictly at the **Parent Tenant** level. Sister concerns receive virtual allocation quotas for sales execution without duplicating inventory records or fragmenting landed-cost accounting.

---

## 2. User Personas & Permissions

| Role | Access Level | Permitted Actions |
| :--- | :--- | :--- |
| **Tenant Admin / Owner** | Full Access | Create & edit shipments, lock landed costs, delete draft/cancelled shipments, manage stock locations & cargo companies. |
| **Warehouse Manager** | Operational | Receive shipments, inspect goods, post stock to warehouse bins, execute bin-to-bin movements, change stock condition grades. |
| **Procurement Staff** | Operational | Create shipment drafts, add catalog/manual line items, enter freight & customs cost entries, track transit milestones. |
| **Sister Concern Staff** | Restricted Read | View virtual allocated stock (`child-stock`), request replenishment quotas. |
| **Auditor / Accountant** | Read Only | View locked shipment books, audit landed cost calculations, inspect stock movement history logs. |

---

## 3. User Stories & Acceptance Criteria

### US-1: Inbound Shipment & Cost Tracking
- **As a** Procurement Officer  
- **I want to** create inbound international shipments, associate suppliers and cargo freight agents, and enter itemized cost entries (goods, freight, customs, local carriage)  
- **So that** landed unit costs are accurately calculated in BDT and apportioned across individual line items.

#### Acceptance Criteria
- [ ] Stamped BDT landed unit cost dynamically accounts for foreign exchange (FX) rates, packaging weight, and custom duty surcharges.
- [ ] Shipments maintain 4 lifecycle states: `draft`, `in_transit`, `received`, and `cancelled`.
- [ ] Cost revisions restamp `landed_cost_bdt` dynamically until books are frozen via `costs_locked = true`.

### US-2: Physical Receiving & Variance Check
- **As a** Warehouse Receiving Staff  
- **I want to** physically verify arrived quantities against shipment manifests on a dedicated receive checklist page  
- **So that** actual received inventory is committed to warehouse pool bins and variance is audited.

#### Acceptance Criteria
- [ ] Setting shipment status to `received` mandatory routes to `ReceiveShipmentPage.vue`.
- [ ] Calling `finalize_global_shipment` commits line items into `global_stocks` rows and stamps initial landed cost.

### US-3: Multi-Tier Warehouse Locations & Movements
- **As a** Warehouse Operator  
- **I want to** organize physical stock into a 4-tier tree (`Warehouse` $\rightarrow$ `Room` $\rightarrow$ `Shelf` $\rightarrow$ `Bin`)  
- **So that** items can be quickly located for order fulfillment and stock audits.

#### Acceptance Criteria
- [ ] Stock items can only reside in leaf-level locations (`bin`).
- [ ] Location transfers and condition grade transitions (`sellable`, `held`, `unsellable`) create immutable `stock_movements` audit logs.

### US-4: Pre-order Demand & Fulfill desks
- **As a** Procurement Officer  
- **I want to** log vendor PO qty on Demand when buying abroad, or skip straight to Fulfill when stock is already in the warehouse  
- **So that** in-stock pre-orders can be picked and invoiced without a fake vendor placement.

#### Acceptance Criteria
- [ ] Demand **Place order** (`placed_quantity`) is optional per line.
- [ ] Fulfill **Pick stock** may run with `placed_quantity = 0`; picks cap at confirmed customer need.
- [ ] **Mark ready for shipment** creates a proforma from picks; backlog = confirmed − allocated picks.

### US-5: Archive-First Shipment Governance
- **As an** Operations Admin  
- **I want to** archive completed, draft, or cancelled shipments without permanently deleting financial records  
- **So that** active tables remain clutter-free while preserving auditability.

#### Acceptance Criteria
- [ ] Active shipment table has no three-dots dropdown menu; each row provides a direct `Archive` button with a confirmation modal.
- [ ] Dedicated toolbar `Archived` hub displays count and opens modal listing all archived shipments.
- [ ] Permanent deletion (`purge_archived_shipment`) is restricted strictly to `draft` and `cancelled` records; `in_transit` and `received` shipments cannot be purged.

### US-6: Batch Code Analyze
- **As a** Procurement Officer  
- **I want** to store batch id, barcode, product code, manufacturing date, and expire date for a shipment  
- **So that** I can see how many days are left until each batch expires.

#### Acceptance Criteria
- [ ] Gear → More → **Batch Code** opens `/:slug/app/procurement/shipment/:id/batch-code`. Grant: `global_shipment`.
- [ ] Each `batch_code_lists` row is tied to exactly one shipment (`shipment_id` required, unique). If a list exists for the shipment, open it; otherwise create `{ parent_tenant_id, shipment_id }`. No list name or vendor on the list.
- [ ] Lines on `batch_code_items` (`list_id` required). Empty expire + mfg → expire = mfg + **36 calendar months**. Hand-edited expire is kept until expire is cleared.
- [ ] **Expires in** is UI-only (`expire_date − today` whole days; shown as months + days, e.g. `2mo 5d`, or **Expired** when due today or past). Whole row **text** color: **red** under **14 months** or expired; **green** when safely past that; **blue** when no expire date. Not stored.
- [ ] Add one line via **Add** dialog. Bulk add / bulk update via column paste and grid paste (`paste_batch_code_items`). Grid cell blur still saves edits. Mfg / expire dates are typed or picked as `DD-MM-YYYY` (stored as date). Calendar starts on year.
- [ ] **Import CSV** on the batch grid: download sample file, fill rows, upload — appends new lines via `paste_batch_code_items` starting at the next row (does not overwrite existing lines). Date columns accept Excel-style `M/D/YYYY` (e.g. `6/27/2026`) as well as `DD-MM-YYYY`.
- [ ] **`is_arrived`** on each `batch_code_items` line (default **false**). Staff tick/untick on the batch grid (saved like other edits). New lines, CSV import, and paste do **not** set arrived.
- [ ] Row checkboxes on the batch grid; when **two or more** lines are selected, **Delete selected** removes them in one action.
- [ ] Procurement hub **Batch Code** lists shipment-linked files only (search by shipment); create only from shipment gear. No write to `global_stocks`.
- [ ] **Shipment line items** table shows a compact **Batch** column (count of matched batch analyze lines, same as rows in the dialog). Tap opens a dialog table of batch ID, expire date, **Expires in**, and **Arrived** (Yes / —) per matched line (same red / green / blue text rules). Bottom form **adds a missing batch** for that line (batch ID, expire `DD-MM-YYYY`, arrived checkbox); creates the shipment batch list if needed and inserts a row with the line’s barcode / product code.

---

## 4. UI Layout & Wireframe

### Inbound Shipment List Screen

```text
+----------------------------------------------------------------------------------------------------+
| Breadcrumbs: App > Operations > Procurement & Stock > Inbound Shipments                            |
+----------------------------------------------------------------------------------------------------+
| [ Search shipments... ] [ Filter: Status v ] [ Vendor v ]   [ Archive Hub (12) ] [ + New Shipment ]|
+----------------------------------------------------------------------------------------------------+
| SHIPMENT #    | VENDOR         | STATUS      | PROGRESS TAG | TOTAL WEIGHT | LANDED TOTAL | ACTION |
|---------------+----------------+-------------+--------------+--------------+--------------+--------|
| SHP-2026-001  | Yiwu Direct    | Received    | Customs Clr  | 420.50 KG    | 540,200 BDT  | [Arch] |
| SHP-2026-002  | Guangzhou Tex  | In Transit  | Air Freight  | 110.00 KG    | 185,000 BDT  | [Arch] |
| SHP-2026-003  | Shenzhen Elec  | Draft       | Order Placed | 85.00 KG     | 92,400 BDT   | [Arch] |
+----------------------------------------------------------------------------------------------------+
| Pagination: Showing 1 - 25 of 148 shipments                                                        |
+----------------------------------------------------------------------------------------------------+
```

### Shipment Detail & Landed Cost Breakdown Screen

```text
+----------------------------------------------------------------------------------------------------+
| Breadcrumbs: Procurement > Shipments > SHP-2026-001                                                |
+----------------------------------------------------------------------------------------------------+
| [ Workflow Bar: Draft > In Transit > [RECEIVED] ]  [ Costs Locked: YES/NO ]  [ Actions / Settings ]|
+----------------------------------------------------------------------------------------------------+
| LINE ITEMS (38)                                     | COST ENTRIES & APPORTIONMENT                 |
| - SKU-001: Cotton Tee (Qty: 500, Landed: 245 BDT)   | - Supplier Goods: 3,500 USD (FX: 122.50)     |
| - SKU-002: Denim Jeans (Qty: 200, Landed: 680 BDT)  | - Air Cargo: 850 USD (Apportioned by Weight) |
| - SKU-003: Bomber Jacket (Qty: 100, Landed: 950 BDT)| - Customs Tariff & Port Charges: 45,000 BDT  |
|                                                     | - Local Trucking: 8,000 BDT                  |
+----------------------------------------------------------------------------------------------------+
```

### Batch Code Analyze Screen

```text
Shipment gear → More → Batch Code
[ Back ] Batch Code — shipment name / #
[ Add line ]  (column paste + grid paste for bulk)
BARCODE | PRODUCT CODE | BATCH ID | MFG DATE | EXPIRE DATE | EXPIRES IN (days, read-only)
```
