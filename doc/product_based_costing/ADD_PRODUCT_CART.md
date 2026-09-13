# Add Product Cart Page

Browse-first catalog for adding products to a product-based costing file.

## Purpose

Staff building a costing quote can browse the product catalog as cards instead of only using the **Add products** drawer (search list + bulk codes).

## Entry points

- **Browse catalog** outline button on the costing file page (header + empty state).
- Route: `/:tenantSlug/app/product-based-costing/:id/add-product-cart`.

## Behavior

| Action | Result |
| :--- | :--- |
| Page load | Shows catalog page 1 (24 items) without requiring search |
| Search / filters | Same vendor, brand, category filters as the add-products drawer |
| **Add to cart** | Creates a costing line on this file with **quantity 1** (ignores MOQ) |
| Already on file | Card shows chip; button disabled |
| Back | Returns to costing file details; new lines visible in the table |

## Out of scope on this page

- Bulk code paste
- Create missing product
- Quantity picker
- Separate checkout cart

Use the **Add products** drawer for bulk codes and create-missing flows.

## Card fields

Image, name, brand, category, product code, barcode, GBP list price, product weight, package weight.
