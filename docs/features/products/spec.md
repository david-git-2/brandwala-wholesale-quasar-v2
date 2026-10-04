# Products & tag catalog — spec

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/products/spec.md` + [00-gaps](00-gaps.md) |
| UI | `web/src/modules/products/` |
| SQL | `public.sql` |
| Model | BW master catalog — [business-models](../../architecture/business-models.md) |
| Access | `app` |

## Where to look

| Need | Path |
| :--- | :--- |
| Products, brands, categories | Grep `products`, `product_brands` in `public.sql` |
| Tags | `web/src/modules/tag/`, tag tables in `public.sql` |
| PC import | Grep `price check` / PC pipeline in `products/` module |
| Pages | `web/src/modules/products/pages/` |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` catalog; shop **reads** via shop_order |
| In | Products, brands, categories, tags, PC import |
| Out | Stock qty, shop listings, Koba products, thrift garments |

See [scopes](../../architecture/scopes.md).

## Personas

| Role | Actions |
| :--- | :--- |
| Catalog admin | Products, brands, categories, tags, PC upload |
| Procurement | Package weights, vendor codes, markets |
| Sales | Search by barcode/title, list prices |
| Auditor | Change history, taxonomies |

## Stories

### US-1: Master product & taxonomy
- SKU/barcode, categories, brands at parent tenant.
  - [ ] Unique barcode/SKU per parent network.
  - [ ] `product_brands`, `product_categories`, `markets`.

### US-2: Price Check (PC) Excel import
- UK spreadsheet bulk ingest.
  - [ ] Headers: `DESCRIPTION`, `PRODUCT CODE`, `BARCODE`, `PIECE PRICE £`, `AVAILABLE UNITS`.
  - [ ] `HAZARDOUS = YES` rows filtered out.

### US-3: Universal tagging (identity invariant)
- Tags for visual classification only — not money, stock, or RBAC.
  - [ ] Condition grades map to `stock_availability`.
  - [ ] Color presets for storefront filters.
