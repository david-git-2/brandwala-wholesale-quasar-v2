# BrandWala Wholesale Master Plan

## Goal

Build this app as an integrated platform with these major areas:

- Order management
- Shipment
- Accounting
- Inventory

Access to features should be controlled on a module basis.

All IDs in this project should use `int`.

Login flow should use the same Google OAuth mechanism for all users, but entry URL and permission checks will differ by route scope.

## Tech Stack

- Frontend: Quasar
- Mobile packaging later: Capacitor for Android
- Backend: Supabase
- Frontend hosting: Cloudflare Pages

Technical requirements:
- Mobile responsiveness is mandatory
- The frontend should be designed so it can later be packaged into Android with Capacitor
- Domain strategy will be finalized later, but the routing model must support:
  - superadmin area on `/platform`
  - tenant internal area on `/app`
  - tenant customer area on `/shop`

## Roles

### Internal

- Superadmin
- Admin
- Staff

### External

- Customer admin
- Customer negotiator
- Customer staff

## MVP 1

### Modules

The platform should support these modules:

- Order management
- Shipment
- Inventory
- Shop costing file
- Costing file
- Accounting
- Invoice

Notes:
- Negotiation is part of the order management workflow, not a separate module
- `tenant_modules` should be used to control tenant-level feature access and navigation visibility

### Module Schema

- `id`
- `key` unique
- `name`
- `description`
- `is_active`

## Core Entities

### Tenant

Purpose:
- Separate businesses

Rules:
- Create, edit, and delete by superadmin
- Read by tenant members

Schema:
- `id`
- `name`
- `slug` unique
- `is_active`
- `created_by`
- `public_domain`

Notes:
- `public_domain` will be used for a dedicated business URL
- `public_domain` should be globally unique
- One tenant represents one separate business

### Membership

Purpose:
- Access management of tenant users for internal roles only

Rules:
- `admin` role can be created only by superadmin
- Admin can create and manage staff
- One email can belong to multiple tenants
- A superadmin can also be an admin in a tenant

Schema:
- `id`
- `name`
- `email`
- `accent_color`
- `tenant_id`
- `role`
- `is_active`
- `added_by`

### Tenant Module

Purpose:
- Auto-generate navigation links
- Control feature access by tenant

Rules:
- Created and managed by superadmin
- Read by all based on tenant access

Schema:
- `id`
- `tenant_id`
- `module_key`
- `is_active`

### Customer Group

Purpose:
- Represent one customer organization under a tenant
- Orders are placed on behalf of the customer group
- Customer-side users use `/shop`

Rules:
- Managed by admin
- Belongs to one tenant
- Used for customer login authorization in the shop flow

Schema:
- `id`
- `name`
- `tenant_id`
- `is_active`

Recommended future fields:
- `created_by`
- `notes`

### Customer Group Member

Purpose:
- Represent individual users inside a customer organization
- These users log in through Google auth and access the shop area

Rules:
- Added and managed under a customer group
- Customer admin can oversee and do all customer actions
- Customer staff can browse products, add to cart, and place draft/order data
- Customer negotiator can confirm orders and negotiate price
- Tenant internal staff cannot work in `/shop`
- Same email can exist in multiple customer groups across different tenants
- Email must be unique inside the same customer group

Schema:
- `id`
- `customer_group_id`
- `name`
- `email`
- `role` (`admin`, `negotiator`, `staff`)
- `is_active`
- `added_by`

Notes:
- Uniqueness should be scoped to the group, for example `(customer_group_id, email)`
- Customer access should be checked by customer-group membership plus tenant context

## UI Entry Points

### `BWWholesale.co/platform`

Denotes the superadmin area.

Features:
- Dashboard
- Tenant management
- Feature table
- Tenant admin add and feature access

### `Tenant Hosting Name /app`

Admin access point.

Features:
- Assign members
- Create customer group
- Manage customer group members
- Work with features

### `Tenant Hosting Name /shop`

Customer entry point.

Features:
- Product list
- Add to cart
- Order placement
- Negotiation flow

Access rules:
- Login uses Google OAuth
- URL is different from internal login
- Access is checked against customer-group membership within the tenant
- Internal tenant members cannot use this area unless they also exist as customer-group members for that tenant

## Notes For Next Planning Pass

- Confirm final table names before migrations
  Suggested names: `customer_groups` and `customer_group_members`
- Confirm audit field references such as `created_by` and `added_by`
- Define exact login RPC design for customer-group access in `/shop`
- Define relationships between order management, shipment, inventory, invoice, and accounting modules
- Define whether order approval and negotiation permissions are role-only or also allow per-order delegation
