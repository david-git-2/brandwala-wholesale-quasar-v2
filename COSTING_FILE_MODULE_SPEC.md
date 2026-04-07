# Costing File Module Specification

This document defines the first implementation contract for the `Costing File` module.

It is intended to be the working source of truth for backend and frontend implementation before UI-specific instructions are added.

## Purpose

The `Costing File` module allows a customer group to submit product requests and allows tenant internal users to enrich, price, and offer those items.

The module supports:

- customer request intake
- internal product enrichment
- cost calculation
- admin offer finalization
- customer-side resale estimate support through buyer profit rate

## Actors

### Customer-side users

- create costing file items by submitting:
  - website URL
  - quantity
  - type
- cannot edit submitted link or quantity later
- can later enter or update buyer profit rate for their own resale estimate

### Staff

Staff can update product enrichment fields only:

- name
- type
- image URL
- product weight
- package weight
- web price GBP
- delivery price GBP

Staff cannot finalize pricing rules or offer decisions.

### Admin

Admin can do all actions in the module, including:

- create costing file
- manage item enrichment
- set conversion rate
- set cargo rates
- set admin profit rate
- review calculated prices
- manually override offer price BDT
- view and edit customer profit rate
- manage costing file workflow state

## Core Flow

### 1. Costing file creation

Tenant admin creates a `costing_file` for a specific customer group.

Rules:

- `customer_group_id` is required
- `tenant_id` is required
- `market` is free text but should be stored in uppercase

### 2. Customer request submission

Customer creates `costing_file_items` under that costing file.

Customer can submit:

- website URL
- quantity
- type

Rules:

- after submission, customer cannot edit website URL or quantity
- item starts in `pending`

### 3. Internal enrichment

Staff or admin adds missing product details:

- name
- type
- image URL
- product weight
- package weight
- web price GBP
- delivery price GBP

### 4. Admin pricing setup

Admin sets file-level pricing inputs:

- conversion rate
- cargo rate 1 KG
- cargo rate 2 KG
- admin profit rate

These file-level values are then used to calculate item pricing dynamically.

### 5. Offer generation

System calculates item-level pricing from the formula rules in this document.

Admin may manually adjust `offer_price_bdt`.

Rule:

- manual admin offer price overwrites the calculated offer price for the final saved value

### 6. Customer-side resale estimate

After admin finalizes the offer, customer can enter `customer_profit_rate`.

This is used to estimate the buyer sell price on the customer side.

Admin can also see and edit this field.

## Workflow State

The module needs two separate levels of state.

### Costing file state

The parent `costing_file` has its own workflow state.

Confirmed rule:

- file state is separate from item state

Implementation note:

- exact file status names should be treated as a controlled enum in implementation
- recommended initial workflow:
  - `draft`
  - `customer_submitted`
  - `in_review`
  - `priced`
  - `offered`
  - `completed`
  - `cancelled`

If product or business naming changes later, the UI and DB should still preserve one parent-level status field.

### Costing file item state

Each `costing_file_item` has a separate status.

Allowed values:

- `pending`
- `accepted`
- `rejected`

Notes:

- `verify` is not a status
- `verify` was only discussion context and should not be modeled as an enum value

## Data Model

## Backend Contract Finalized

This section is the implementation contract for backend work.

### Parent table

Use table name:

- `costing_files`

### Child table

Use table name:

- `costing_file_items`

### Real foreign key targets

`costing_files` must reference:

- `tenant_id -> public.tenants(id)`
- `customer_group_id -> public.customer_groups(id)`

`costing_file_items` must reference:

- `costing_file_id -> public.costing_files(id)`

### Actor linkage

The current backend does not have one shared actor table for both app-side users and customer-side users.

Because costing actions may come from:

- `public.memberships`
- `public.customer_group_members`

the initial backend contract should store:

- `created_by_email`

This should default to `public.current_user_email()`.

If stricter actor references are needed later, they can be added as separate actor-link fields in a later step.

### File status contract

Use a controlled backend enum or check constraint with these exact values:

- `draft`
- `customer_submitted`
- `in_review`
- `priced`
- `offered`
- `completed`
- `cancelled`

### Item status contract

Use a controlled backend enum or check constraint with these exact values:

- `pending`
- `accepted`
- `rejected`

### Required fields on `costing_files`

- `id`
- `name`
- `market`
- `status`
- `customer_group_id`
- `tenant_id`
- `created_by_email`
- `created_at`
- `updated_at`

### Optional file-level pricing fields on `costing_files`

- `cargo_rate_1kg`
- `cargo_rate_2kg`
- `conversion_rate`
- `admin_profit_rate`

These may start as nullable and become required when the file reaches pricing stages.

### Required fields on `costing_file_items`

- `id`
- `costing_file_id`
- `website_url`
- `quantity`
- `status`
- `created_by_email`
- `created_at`
- `updated_at`

### Optional enrichment and pricing fields on `costing_file_items`

- `name`
- `image_url`
- `product_weight`
- `package_weight`
- `price_in_web_gbp`
- `delivery_price_gbp`
- `auxiliary_price_gbp`
- `item_price_gbp`
- `cargo_rate`
- `costing_price_gbp`
- `costing_price_bdt`
- `offer_price_override_bdt`
- `offer_price_bdt`
- `customer_profit_rate`

### Stored vs derived decision

Store in database:

- file-level pricing inputs
- item request fields
- item enrichment fields
- final calculated pricing snapshots needed for workflow and audit:
  - `auxiliary_price_gbp`
  - `item_price_gbp`
  - `cargo_rate`
  - `costing_price_gbp`
  - `costing_price_bdt`
  - `offer_price_bdt`
- manual override input:
  - `offer_price_override_bdt`

Do not store:

- `total_weight`
- `buyer_sell_price`

These should be derived when needed.

### Override decision

- `offer_price_override_bdt` stores the manual override input when admin sets one
- `offer_price_bdt` is the final saved offer value after calculation or override application
- if `offer_price_override_bdt` is present, it replaces the calculated offer result for persisted `offer_price_bdt`

### Normalization rules

- `market` must be stored as uppercase
- `website_url` should be stored trimmed
- status fields should be stored in lowercase enum values
- weight fields should be integers in grams
- GBP fields should use numeric with 2-decimal precision
- BDT fields should use integer values

### Suggested data types

`costing_files`

- `id bigserial primary key`
- `name text not null`
- `market text not null`
- `status text or enum not null`
- `cargo_rate_1kg numeric(12,2)`
- `cargo_rate_2kg numeric(12,2)`
- `conversion_rate numeric(12,2)`
- `admin_profit_rate numeric(12,2)`
- `customer_group_id bigint not null references public.customer_groups(id) on delete cascade`
- `tenant_id bigint not null references public.tenants(id) on delete cascade`
- `created_by_email text not null default public.current_user_email()`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

`costing_file_items`

- `id bigserial primary key`
- `costing_file_id bigint not null references public.costing_files(id) on delete cascade`
- `name text`
- `image_url text`
- `website_url text not null`
- `quantity integer not null`
- `product_weight integer`
- `package_weight integer`
- `price_in_web_gbp numeric(12,2)`
- `delivery_price_gbp numeric(12,2)`
- `auxiliary_price_gbp numeric(12,2)`
- `item_price_gbp numeric(12,2)`
- `cargo_rate numeric(12,2)`
- `costing_price_gbp numeric(12,2)`
- `costing_price_bdt integer`
- `offer_price_override_bdt integer`
- `offer_price_bdt integer`
- `customer_profit_rate numeric(12,2)`
- `status text or enum not null`
- `created_by_email text not null default public.current_user_email()`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

### Required indexes

- index on `costing_files(tenant_id)`
- index on `costing_files(customer_group_id)`
- index on `costing_files(status)`
- index on `costing_file_items(costing_file_id)`
- index on `costing_file_items(status)`

### Backend scope decision for next step

The next backend schema step should implement:

- both tables
- both status constraints
- foreign keys
- timestamps
- `updated_at` triggers
- normalization for `market`

## `costing_files`

Recommended fields:

- `id`
- `name`
- `cargo_rate_1kg`
- `cargo_rate_2kg`
- `conversion_rate`
- `admin_profit_rate`
- `status`
- `market`
- `customer_group_id`
- `tenant_id`
- `created_by`
- `created_at`
- `updated_at`

Notes:

- `market` should be normalized to uppercase
- `customer_group_id` must always be linked
- file-level rates are saved here and used later in item calculations

## `costing_file_items`

Recommended fields:

- `id`
- `costing_file_id`
- `name`
- `image_url`
- `website_url`
- `quantity`
- `product_weight`
- `package_weight`
- `offer_price_bdt`
- `item_price_gbp`
- `costing_price_gbp`
- `costing_price_bdt`
- `delivery_price_gbp`
- `admin_profit_rate`
- `customer_profit_rate`
- `status`
- `price_in_web_gbp`
- `auxiliary_price_gbp`
- `cargo_rate`
- `created_by`
- `created_at`
- `updated_at`

Notes:

- `costing price gap` was clarified as `costing_price_gbp`
- `conning file id` was clarified as `costing_file_id`
- `cargo_rate` on the item is derived dynamically from file-level cargo-rate settings and current price conditions
- `total_weight` should not be stored; it should be calculated when needed

## Field Meaning

### Weight fields

- `product_weight` is in grams
- `package_weight` is in grams
- weights should be integer values
- total weight is calculated:
  - `total_weight = product_weight + package_weight`

### Price fields

- all GBP values keep 2 decimal places
- BDT values are integer values
- BDT values must be rounded upward to the nearest value ending in `0` or `5`

Examples:

- `41 -> 45`
- `45 -> 45`
- `46 -> 50`

## Calculation Rules

Create a separate JavaScript file for calculation logic only.

The pricing formulas should not be spread across UI components.

### 1. Total weight

```text
total_weight = product_weight + package_weight
```

Notes:

- unit is grams
- do not store this field in database

### 2. Auxiliary price GBP

Let:

```text
base_price_gbp = price_in_web_gbp + delivery_price_gbp
```

Then:

```text
if base_price_gbp <= 10:
  auxiliary_price_gbp = 0

if base_price_gbp > 10 and base_price_gbp <= 100:
  auxiliary_price_gbp = 2

if base_price_gbp > 100:
  auxiliary_price_gbp = 2 + CEILING((base_price_gbp - 100) / 50, 1)
```

Source sheet logic:

```text
=IF(X4<=10,0,IF(X4<=100,2,2+CEILING((X4-100)/50,1)))
```

### 3. Item price GBP

```text
item_price_gbp = price_in_web_gbp + delivery_price_gbp + auxiliary_price_gbp
```

### 4. Item cargo rate selection

Cargo rate is selected after `item_price_gbp` is known.

Rule:

```text
if item_price_gbp > 10:
  cargo_rate = costing_file.cargo_rate_2kg
else:
  cargo_rate = costing_file.cargo_rate_1kg
```

Default behavior:

- cargo rate may be `0` until enough data exists to calculate it

### 5. Costing price GBP

```text
costing_price_gbp = item_price_gbp + (total_weight / 1000) * cargo_rate
```

### 6. Costing price BDT

```text
costing_price_bdt = costing_price_gbp * conversion_rate
```

Then apply BDT rounding rule:

- round upward to nearest integer ending in `0` or `5`

### 7. Offer price BDT

Calculated offer:

```text
offer_price_bdt = costing_price_bdt + (costing_price_bdt * admin_profit_rate / 100)
```

Then apply BDT rounding rule:

- round upward to nearest integer ending in `0` or `5`

Final save rule:

- if admin manually edits offer price BDT, the manual value overwrites the calculated value

### 8. Buyer sell price

```text
buyer_sell_price = offer_price_bdt + (offer_price_bdt * customer_profit_rate / 100)
```

Then apply BDT rounding rule if the UI or API persists this value.

Note:

- this price is mainly for customer-side approximation and resale planning

## Permission Summary

### Customer

- create costing file items with website URL and quantity
- view offered pricing
- set or update customer profit rate later
- cannot edit original website URL and quantity after submission

### Staff

- view costing files
- add or edit:
  - name
  - image URL
  - product weight
  - package weight
  - web price GBP
  - delivery price GBP
- cannot finalize pricing rules or override offer price

### Admin

- full access to costing file and item data
- manage workflow state
- set pricing rules
- override offer price
- edit customer profit rate

## UI and API Notes

- file totals are not required for the first version
- UI can calculate summary values as needed without storing extra total fields
- calculations should be centralized in one JS utility/module
- avoid duplicating pricing logic between frontend forms and backend payload builders

## Implementation Notes

- use `int` IDs to stay aligned with project rules
- keep parent and child statuses separate
- preserve dynamic calculation behavior for item cargo rate and total weight
- normalize `market` to uppercase in input handling or persistence layer
- keep pricing calculations deterministic and reusable

## Out Of Scope For This Spec

- final UI layout
- screen-by-screen interaction design
- notifications
- audit-history display
- aggregate reporting
- file-level totals persistence

UI instructions can be layered on top of this spec in the next step.
