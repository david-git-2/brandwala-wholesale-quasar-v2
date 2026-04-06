# Costing File RLS and Access Rules

## Goal

The costing file feature uses row-level security and helper functions to decide who can:

- view a file
- create a file
- add or remove items
- update enrichment fields
- see offered or completed work

The database, not just the UI, enforces these rules.

## Actor types

### Superadmin

- Can manage system-wide data.
- Can see and manage internal costing files according to the visibility rules.

### Tenant admin

- Can manage costing files in their tenant.

### Staff

- Can access files in their tenant when the workflow allows it.
- Can enrich items and participate in review work.

### Customer

- Can access files for their customer group.
- Can create and manage draft items only when the file belongs to them and the workflow allows it.

## Helper functions

These functions are the core of the policy layer:

- `is_tenant_staff(tenant_id)`
- `is_customer_group_member(customer_group_id)`
- `can_admin_manage_costing_file(tenant_id)`
- `can_staff_access_costing_file(tenant_id)`
- `can_customer_access_costing_file(customer_group_id)`
- `can_view_costing_file(costing_file_id)`
- `current_costing_item_actor_role(costing_file_id)`

## File visibility

### `can_view_costing_file(costing_file_id)`

The current rule set allows:

- admin access when the file is internal or has progressed to customer-submitted, offered, completed, or cancelled
- staff access when the file is `customer_submitted`
- customer access when the customer belongs to the group and either:
  - the file was created by that customer, or
  - the file is `offered` and the file was created by an internal tenant user

This means customer-created files remain visible to the creator.
Staff/admin-created files are shown to customers when the workflow reaches the offer path.

## Table policies

### `costing_files`

- `select`: admin, staff, or customer group member via `can_view_costing_file`
- `insert`: admin only
- `update`: admin only
- `delete`: admin only

### `costing_file_items`

- `select`: allowed through `can_view_costing_file(costing_file_id)`
- `insert`: admin, staff, or customer draft creator when:
  - file status is `draft`
  - the customer belongs to the file group
  - `created_by_email` matches the current user
- `update`: allowed through `can_view_costing_file(costing_file_id)`, but triggers restrict what each actor may change
- `delete`: admin, staff, or customer draft creator when the same draft ownership rule applies

## Trigger enforcement

The trigger `enforce_costing_file_item_update_rules()` is the second layer of protection.

### Admin

- Can update anything on the item.

### Staff

- Can update enrichment-related fields only.
- Cannot change ownership or customer-level decision fields.

### Customer, draft file

- Can update only the limited draft fields allowed by the trigger.

### Customer, offered file

- Can update item decision fields only.

## RPCs used by the frontend

### File list

- `list_costing_files_for_actor`
- Used by admin, staff, and customer list pages

### File details

- `get_costing_file_by_id`
- Used by admin/staff and customer details loading

### Item listing

- `list_costing_file_items`
- Used in privileged views

### Item creation

- `create_costing_file_item_request`
- Used for customer draft entry

### Item update helpers

- `update_costing_file_item_enrichment`
- `update_costing_file_item_customer_profit`
- `update_costing_file_items_customer_profit`
- `update_costing_file_item_status`
- `update_costing_file_item_offer`
- `update_costing_file_item`

## Important behavior to remember

1. A customer-created draft file stays visible to that customer.
2. Customers can add and delete draft items only on files they created.
3. Customers do not get full pricing visibility until the file is offered.
4. The UI mirrors these rules, but the database policies and trigger are the real enforcement layer.
