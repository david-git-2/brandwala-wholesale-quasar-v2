# Products & Tag Catalog — Product Requirements Document (PRD)

> **Module**: Master Merchandise Catalog, Taxonomy & Universal Tagging System  
> **Status**: Approved & Active  
> **Target Release**: v2.4.0  
> **Target Audience**: Catalog Managers, Sourcing Specialists, Inventory Clerks, Storefront Admins

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/products/` |
| UI | `web/src/modules/products/` |
| SQL | `public.sql` |
| Access | `app` |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` catalog; shop **reads** products via shop_order |
| In | Products, brands, categories, tags, PC import |
| Out | Stock qty, shop listings, Koba products, thrift garments |

See [scopes](../../architecture/scopes.md).

---

## 1. Executive Summary

The **Products & Tag Catalog** domain manages the platform's master catalog of merchandise, vendor SKUs, barcodes, brands, hierarchical categories, package weight specifications, and the Universal Tagging System.

Products are owned at the **Parent Tenant** warehouse level. Sister concerns read the master catalog to create sales invoices, list storefront products, and execute procurement orders. The Universal Tagging System provides a platform-wide dictionary for visual classification (stock condition grades, color swatches) without corrupting financial ledgers or access control gates.

---

## 2. User Personas & Permissions

| Role | Access Level | Permitted Actions |
| :--- | :--- | :--- |
| **Catalog Administrator** | Full Access | Create/edit products, manage brands & categories, configure universal tags, upload Price Check spreadsheets. |
| **Procurement Specialist** | Operational | Update product package weights, assign vendor codes, associate sourcing markets. |
| **Sales Operator** | Read Only | Search catalog products by barcode or title, view reference list prices. |
| **Auditor** | Read Only | View product change history and brand taxonomies. |

---

## 3. User Stories & Acceptance Criteria

### US-1: Master Product & Taxonomy Management
- **As a** Catalog Administrator  
- **I want to** create and maintain master products with SKU barcodes, category trees, and brand associations  
- **So that** inventory, sales desks, and storefronts have consistent product definitions.

#### Acceptance Criteria
- [ ] Products are unique per barcode/SKU within the parent tenant network.
- [ ] Supports master taxonomy associations (`product_brands`, `product_categories`, `markets`).

### US-2: Price Check (PC) Excel Import Pipeline
- **As a** Sourcing Specialist  
- **I want to** import UK Price Check spreadsheets via bulk batch upload  
- **So that** hundreds of new supplier items are ingested with automated brand/category upserts.

#### Acceptance Criteria
- [ ] Auto-maps spreadsheet headers (`DESCRIPTION`, `PRODUCT CODE`, `BARCODE`, `PIECE PRICE £`, `AVAILABLE UNITS`).
- [ ] Rows marked `HAZARDOUS = YES` are automatically filtered out during ingestion.

### US-3: Universal Tagging & The Identity Invariant
- **As a** System Architect  
- **I want to** use universal tags strictly for visual classification (condition grades, color badges, progress labels)  
- **So that** business-critical concerns (money, stock availability, RBAC) remain strictly enforced by database schemas and enums.

#### Acceptance Criteria
- [ ] Stock condition grades (`standard`, `open_box`, `box_damage`, `badly_damaged`) map cleanly to `stock_availability` states.
- [ ] Color presets provide consistent hex swatches for storefront filtering.

---

## 4. UI Layout & Wireframe

### Product Master Catalog Screen

```text
+----------------------------------------------------------------------------------------------------+
| Breadcrumbs: App > Catalog > Products Master                                                       |
+----------------------------------------------------------------------------------------------------+
| [ Search products, SKU, barcode... ] [ Category: All v ] [ Brand: All v ]     [ + Create Product ] |
+----------------------------------------------------------------------------------------------------+
| IMAGE | PRODUCT NAME / CODE     | BRAND       | CATEGORY    | BARCODE       | LIST PRICE | WEIGHT  |
|-------+-------------------------+-------------+-------------+---------------+------------+---------|
| [Img] | Cotton Polo Shirt (CP-4)| Brandwala   | Apparel     | 8901234567890 | £ 4.50     | 0.25 KG |
| [Img] | Bomber Flight Jacket    | Alpha Wear  | Outerwear   | 8901234567891 | £ 18.00    | 0.85 KG |
| [Img] | Leather Bifold Wallet   | Heritage BD | Accessories | 8901234567892 | £ 8.00     | 0.15 KG |
+----------------------------------------------------------------------------------------------------+
| Pagination: Showing 1 - 25 of 1,240 Master Products                                                |
+----------------------------------------------------------------------------------------------------+
```
