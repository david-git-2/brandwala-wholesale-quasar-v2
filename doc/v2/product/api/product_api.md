# Product API Specification

This document details the REST APIs and Supabase queries used for managing products, brands, and categories.

---

## 1. Product CRUD Operations

### 1.1 List Products (Paginated via RPC)
Retrieves a paginated list of products with search, sorting, and filtering options.

* **RPC**: `list_products_paginated`
* **Method**: `supabase.rpc('list_products_paginated', payload)`

#### Payload Parameters
| Parameter | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `p_tenant_id` | INTEGER | No | Tenant ID scoping |
| `p_search` | STRING | No | Search term matching name, code, or barcode |
| `p_search_field` | STRING | No | Targeted field search (`'name'`, `'product_code'`, `'barcode'`) |
| `p_brand` | STRING | No | Filter by brand |
| `p_category` | STRING | No | Filter by category |
| `p_vendor_code` | STRING | No | Filter by vendor code |
| `p_market_code` | STRING | No | Filter by market code (e.g. `BD_LOCAL`) |
| `p_is_available` | BOOLEAN | No | Filter by availability status |
| `p_limit` | INTEGER | No | Items per page (default `50`) |
| `p_offset` | INTEGER | No | Pagination offset |
| `p_sort_by` | STRING | No | Column to sort by (e.g. `'name'`, `'created_at'`) |
| `p_sort_dir` | STRING | No | Sort direction (`'asc'` or `'desc'`) |

---

### 1.2 Create Product
Inserts a new product record into `products`.

* **Table**: `products`
* **Method**: `supabase.from('products').insert(payload)`

#### Request Payload
```json
{
  "tenant_id": 15,
  "product_code": "PROD-1001",
  "barcode": "501234567890",
  "name": "Organic Honey 500g",
  "brand": "Nature Best",
  "category": "Food & Beverage",
  "vendor_id": 4,
  "vendor_code": "VEN-UK01",
  "market_code": "UK_MARKET",
  "list_price_amount": 12.50,
  "list_price_currency_id": 2,
  "reference_cost_amount": 7.00,
  "reference_cost_currency_id": 2,
  "available_units": 100,
  "minimum_order_quantity": 5,
  "product_weight": 0.50,
  "package_weight": 0.05,
  "is_available": true
}
```

---

### 1.3 Bulk Create Products (Batch Insert)
Inserts multiple product records in a single batch REST request.

* **Table**: `products`
* **Method**: `supabase.from('products').insert(arrayPayloads).select()`

#### Request Payload
JSON Array of product objects:
```json
[
  {
    "tenant_id": 15,
    "product_code": "PROD-1001",
    "name": "Organic Honey 500g",
    "list_price_amount": 12.50
  },
  {
    "tenant_id": 15,
    "product_code": "PROD-1002",
    "name": "Olive Oil 1L",
    "list_price_amount": 18.00
  }
]
```

---

### 1.4 Update Product (Partial / PATCH Style)
Updates specified fields of an existing product. Only send changed fields.

* **Table**: `products`
* **Method**: `supabase.from('products').update(payload).eq('id', productId)`

#### Request Payload Example
```json
{
  "list_price_amount": 14.00,
  "product_weight": 0.52,
  "is_available": true
}
```

---

### 1.5 Delete Product
Deletes a product by primary key.

* **Table**: `products`
* **Method**: `supabase.from('products').delete().eq('id', productId)`

---

## 2. Product Brands & Categories APIs

### 2.1 List Brands
* **Table**: `product_brands`
* **Query**: `supabase.from('product_brands').select('*').eq('tenant_id', tenantId)`

### 2.2 List Categories
* **Table**: `product_categories`
* **Query**: `supabase.from('product_categories').select('*').eq('tenant_id', tenantId)`
