# Thrift Vertical — Product Requirements Document (PRD)

> **Module**: Second-Hand, Vintage & One-Off Garment Retail System  
> **Status**: Approved & Active  
> **Target Release**: v2.4.0  
> **Target Audience**: Thrift Shop Managers, Tagging Clerks, POS Cashiers, Store Operators

---

## 1. Executive Summary

The **Thrift Vertical** is a complete, specialized retail operations system tailored for one-of-a-kind second-hand merchandise and vintage apparel.

It manages box-level intake shipments, landed unit cost allocation by weight, physical garment measurement capture (chest, waist, inseam, rise), Code-128 barcode generation, POS sales desk checkout with customer courier risk verification, and post-delivery return restock.

---

## 2. User Personas & Permissions

| Role | Access Level | Permitted Actions |
| :--- | :--- | :--- |
| **Thrift Shop Manager** | Full Access | Create intake shipments, calculate box landed costs, set retail price formulas, approve returns, view financial glance dashboards. |
| **Stock Tagging Clerk** | Operational | Register unique SKUs, record garment measurements, print thermal barcode labels and marketing hang-tags. |
| **POS Sales Clerk** | Operational | Scan barcodes at checkout, verify customer risk scores, dispatch parcels via courier COD. |
| **Auditor** | Read Only | View thrift sales reports, margin breakdowns, and unsold inventory aging. |

---

## 3. User Stories & Acceptance Criteria

### US-1: Landed Unit Costing & Ceiling Pricing Engine
- **As a** Thrift Operations Lead  
- **I want to** apportion freight charges across unique garment items by weight and automatically compute retail ceiling prices  
- **So that** one-off pieces are priced profitably with standardized rounded price points.

#### Acceptance Criteria
- [ ] Formula calculates: $\text{Landed Cost} = \text{Origin Cost} + \text{Apportioned Cargo (Weight)} + \text{Packaging/Tag Cost}$.
- [ ] Auto-listed price applies ceiling presets: $\text{Price} = \text{Ceil}_{\text{preset}}(\text{Landed Cost} \times (1 + \text{Markup}))$.

### US-2: Garment Measurement Capture & Fit Visualizer
- **As a** Tagging Clerk  
- **I want to** record physical dimensions (inches) for Tops and Bottoms and print marketing hang-tags  
- **So that** online and in-store buyers know the exact garment fit.

#### Acceptance Criteria
- [ ] Captures Chest, Body Length, Shoulder, and Sleeve for Tops; Waist, Inseam, Outseam, Rise, Thigh for Bottoms.
- [ ] Hang-tag printer generates printable PDF voucher with brand name, size, measurements, barcode, and retail price.

### US-3: POS Sales Checkout & Courier Delivery Risk Scoring
- **As a** POS Cashier  
- **I want to** scan barcode tags and instantly verify customer phone delivery history before issuing courier COD invoices  
- **So that** high-risk delivery cancellations are identified prior to dispatch.

#### Acceptance Criteria
- [ ] `create_thrift_sales_invoice` commits sold inventory in a single atomic transaction.
- [ ] `get_thrift_customer_sales_risk` returns parcel delivery completion rates and cancellation flags.

---

## 4. UI Layout & Wireframe

### Thrift Stock Inventory & POS Screen

```text
+----------------------------------------------------------------------------------------------------+
| Breadcrumbs: App > Thrift > Stock Inventory                                                        |
+----------------------------------------------------------------------------------------------------+
| [ Barcode Scanner / Search... ] [ Category: Tops v ] [ Status: In Stock v ]   [ + Register Garment ]|
+----------------------------------------------------------------------------------------------------+
| BARCODE      | ITEM NAME / BRAND       | SIZE | MEASUREMENTS         | LANDED BDT | RETAIL PRICE   |
|--------------+-------------------------+------+----------------------+------------+----------------|
| TH-100293    | Vintage Levi's 501      | W32  | W: 32", Inseam: 30"  | 850.00 BDT | 1,800.00 BDT   |
| TH-100294    | Ralph Lauren Polo Shirt | L    | Chest: 44", L: 28"   | 420.00 BDT | 950.00 BDT     |
| TH-100295    | Carhartt Detroit Jacket | XL   | Chest: 48", L: 27"   | 1,450.0 BDT| 3,200.00 BDT   |
+----------------------------------------------------------------------------------------------------+
| [ Print Selected Tags ]   [ Batch Barcode Roll (100) ]              [ Open POS Sales Checkout ]    |
+----------------------------------------------------------------------------------------------------+
```
