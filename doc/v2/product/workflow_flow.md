# Product Lifecycle & Workflow Specification

This document details the step-by-step business flow for product catalog management, indexing, stock synchronization, and store distribution.

---

## Lifecycle Overview

```mermaid
flowchart TD
    subgraph Stage1["Stage 1: Catalog Provisioning"]
        A["Create/Import Product"]
        B["Assign Brand, Category & Vendor"]
        A --> B
    end

    subgraph Stage2["Stage 2: Pricing & Stock Management"]
        C["Update Reference Costs & List Prices"]
        D["Receive Shipment & Update Stock (available_units)"]
        B --> C
        C --> D
    end

    subgraph Stage3["Stage 3: Integration & Distribution"]
        E["Storefront Display (RPC: list_products_paginated)"]
        F["Procurement / Shipment Weight Sync"]
        D --> E
        D --> F
    end
```

---

## Stage 1: Product Provisioning & Import

* **Action**: Tenant admin creates a single product or imports a bulk product batch.
* **Attributes**: `name`, `product_code`, `barcode`, `market_code`, `vendor_id`, `brand`, `category`.
* **API Used**:
  * **Single Create**: `supabase.from('products').insert(singleObject)`
  * **Bulk Import (Batch)**: `supabase.from('products').insert(arrayPayloads).select()` (Sends multiple items in a single HTTP batch request to the `products` table endpoint)

---

## Stage 2: Costing, Pricing & Weight Sync

* **Action**: Update reference costs, list prices, and physical package/product weights.
* **Weight Synchronization**: When processing incoming shipments, unit product weight and package weight are calculated and synced back to `products` (`product_weight`, `package_weight`).
* **API Used**: `supabase.from('products').update(...)`

---

## Stage 3: Querying & Store Distribution

* **Paginated Search & Filter**:
  * Filter catalog by brand, category, vendor code, market code, availability, or free text search.
  * **RPC Function**: `list_products_paginated`
* **Bulk Lookup**:
  * Procurement tools look up products by `product_code` or `barcode` to quickly add items to shipments or orders.
