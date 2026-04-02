# Costing File Implementation Steps

This guide is now focused on the real implementation of the `Costing File` module.

Use [COSTING_FILE_MODULE_SPEC.md](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/COSTING_FILE_MODULE_SPEC.md) as the feature source of truth.

## Goal

Build the full feature in production order:

1. backend first
2. frontend second
3. verify the full flow end to end

This is not a mock plan.

## Working Rule

Do the work in small passes:

1. complete one step
2. verify it works
3. move to the next step

## UI Consistency Rule

For simple data entry and list screens across the app, prefer simple UI:

- use a plain page header
- use direct input fields and one clear primary action
- use simple tables for row data
- use icon actions for row edit and delete
- avoid heavy cards, stacked helper sections, and decorative table wrappers unless they add real value

## Step 1. Finalize Backend Data Contract

Goal:

Lock the exact backend shape before writing UI behavior.

Scope:

- confirm `costing_files` fields
- confirm `costing_file_items` fields
- confirm file status enum values
- confirm item status enum values
- confirm required foreign keys
- confirm which calculated values are stored and which are derived

Expected result:

- one clear backend contract exists for database, policies, RPC, and frontend integration

## Step 2. Create Backend Schema

Goal:

Implement the database layer for the feature.

Scope:

- create `costing_files`
- create `costing_file_items`
- add constraints
- add indexes
- add file status constraint or enum
- add item status constraint or enum
- normalize `market` to uppercase
- ensure `customer_group_id` and `tenant_id` are required on `costing_files`
- ensure `costing_file_id` is required on `costing_file_items`

Expected result:

- the database structure is ready for real feature usage

## Step 3. Add Backend Access Rules

Goal:

Enforce the confirmed role behavior on the backend.

Scope:

- add RLS policies for admin
- add RLS policies for staff
- add RLS policies for customer-side users
- customer can create item requests
- customer cannot update submitted `website_url` and `quantity`
- customer can update `customer_profit_rate`
- staff can update only enrichment fields
- admin can manage all fields and workflow state
- item status supports:
  - `pending`
  - `accepted`
  - `rejected`

Expected result:

- the permission rules are enforced by backend, not only by UI

## Step 4. Add Backend Write Helpers

Goal:

Create a clean backend API for the frontend to call.

Scope:

- create costing file
- list costing files by tenant and customer-group context
- get costing file details
- create costing file item request
- update staff enrichment fields
- update admin pricing fields
- update customer profit rate
- update item status
- update file status

Expected result:

- frontend can use stable backend entry points instead of writing raw logic everywhere

## Step 5. Add Centralized Calculation Logic

Goal:

Implement the pricing rules in one place.

Scope:

- create one dedicated JavaScript or TypeScript calculation file
- calculate total weight
- calculate auxiliary price GBP
- calculate item price GBP
- select cargo rate dynamically
- calculate costing price GBP
- calculate costing price BDT
- calculate offer price BDT
- calculate buyer sell price
- apply GBP decimal rules
- apply BDT round-up-to-0-or-5 rules
- keep formulas out of page components

Expected result:

- all pricing logic is centralized and reusable

## Step 6. Connect Backend Calculations To Data Flow

Goal:

Make backend and calculation logic work together consistently.

Scope:

- decide when calculated values are recomputed
- populate stored calculated fields if the schema requires them
- ensure admin override replaces calculated offer price
- ensure customer profit updates buyer sell price correctly
- ensure total weight stays derived and is not stored

Expected result:

- saved records and displayed values stay consistent

## Step 7. Build Admin Frontend

Goal:

Implement the real admin UI on top of backend data.

Scope:

- create costing file page with minimal create form:
  - name
  - market
- show costing file list
- open details on click
- show product list in table format
- allow admin editing for:
  - workflow state
  - enrichment fields
  - pricing fields
  - offer override
  - customer profit rate
  - item status

Expected result:

- admin can perform the full costing workflow from the real UI

## Step 8. Build Staff Frontend

Goal:

Implement the real staff UI on top of backend data.

Scope:

- show costing file list
- open costing file details
- show product list in table format
- allow staff editing only for:
  - name
  - image URL
  - product weight
  - package weight
  - web price GBP
  - delivery price GBP
- keep pricing controls and workflow controls unavailable

Expected result:

- staff can do enrichment only, with backend-backed restrictions

## Step 9. Build Customer Frontend

Goal:

Implement the real customer UI on top of backend data.

Scope:

- show costing file list relevant to the customer group
- open costing file details
- show product list in table format
- allow customer to create item request rows:
  - website URL
  - quantity
- keep submitted `website_url` and `quantity` read-only later
- allow customer to update `customer_profit_rate`
- show offer and buyer sell calculations

Expected result:

- customer can submit requests and later use buyer profit planning on the real feature

## Step 10. Verify End To End

Goal:

Confirm the real feature works across backend and frontend.

Verify:

- admin can create a costing file
- customer can add item requests
- staff can enrich item data
- admin can enter pricing inputs and finalize offer
- customer can enter buyer profit rate later
- calculated fields update correctly
- backend restrictions block invalid updates
- frontend matches backend permissions

Expected result:

- the module is ready for refinement, testing, and rollout
