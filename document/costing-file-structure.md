# Costing File Structure

## Purpose

The costing file module lets a tenant manage a customer-specific costing workflow.
It starts with a draft file, moves through review, and ends with an offered or completed outcome.

## Main entities

### `costing_files`

This is the parent record for the whole workflow.

Important fields:

- `id`: primary key
- `name`: display name of the costing file
- `market`: market label such as `US`, `GB`, or `BD`
- `status`: workflow state
- `customer_group_id`: which customer group owns the file
- `tenant_id`: tenant ownership
- `created_by_email`: who created the file
- `cargo_rate_1kg`, `cargo_rate_2kg`, `conversion_rate`, `admin_profit_rate`: pricing inputs managed by admin/staff
- `created_at`, `updated_at`: timestamps

### `costing_file_items`

This table stores the products or requests inside a costing file.

Important fields:

- `id`: primary key
- `costing_file_id`: foreign key to `costing_files.id`
- `website_url`: product link
- `quantity`: number of units
- `name`: product name
- `size`: customer-entered size field
- `color`: customer-entered color field
- `extra_information_1`: customer-entered free-text slot
- `extra_information_2`: customer-entered free-text slot
- `image_url`: product image
- `product_weight`, `package_weight`: enrichment fields
- `price_in_web_gbp`, `delivery_price_gbp`: web pricing inputs
- `auxiliary_price_gbp`, `item_price_gbp`, `cargo_rate`: calculated or staff-managed pricing inputs
- `costing_price_gbp`, `costing_price_bdt`, `offer_price_override_bdt`, `offer_price_bdt`: costing and offer outputs
- `customer_profit_rate`: customer-side profit setting
- `status`: item-level status
- `created_by_email`, `created_at`, `updated_at`: audit fields

## Item fields by role

### Customer-created draft items

Customers can enter:

- `website_url`
- `quantity`
- `size`
- `color`
- `extra_information_1`
- `extra_information_2`

### Staff/admin item enrichment

Staff and admins can add or edit:

- `name`
- `image_url`
- `product_weight`
- `package_weight`
- `price_in_web_gbp`
- `delivery_price_gbp`
- pricing and offer fields used by the costing engine

## Statuses

### File statuses

From the generated Supabase types:

- `draft`
- `customer_submitted`
- `in_review`
- `priced`
- `offered`
- `completed`
- `cancelled`

### Item statuses

- `pending`
- `accepted`
- `rejected`

## Frontend flow

### Customer flow

1. Customer creates a draft costing file.
2. If the file was created by that same customer, they can add and delete draft items.
3. In draft and review-related states, the customer table shows only the customer-entered fields.
4. When the file becomes `offered`, the customer sees the offer and can accept or reject items.

### Staff/admin flow

1. Staff/admin can manage files inside the tenant.
2. They can enrich item details and drive the costing workflow.
3. They can see broader pricing details in admin and staff views.

## Frontend modules

- `web/src/modules/costingFile/pages/CustomerCostingFilePage.vue`
- `web/src/modules/costingFile/pages/CustomerCostingFileDetailsPage.vue`
- `web/src/modules/costingFile/pages/AdminCostingFilePage.vue`
- `web/src/modules/costingFile/pages/AdminCostingFileDetailsPage.vue`
- `web/src/modules/costingFile/pages/StaffCostingFilePage.vue`
- `web/src/modules/costingFile/pages/StaffCostingFileDetailsPage.vue`
- `web/src/modules/costingFile/composables/useCostingFileDetailRows.ts`
- `web/src/modules/costingFile/repositories/costingFileRepository.ts`
- `web/src/modules/costingFile/repositories/costingFileItemRepository.ts`

## Notes

- Customer-facing views intentionally hide sensitive pricing fields until the workflow reaches the offer stage.
- The database still enforces the same rules with RLS and trigger logic, so the frontend is not the only protection.
