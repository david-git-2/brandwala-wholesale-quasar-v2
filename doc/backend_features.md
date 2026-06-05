# Backend Architecture & Features Documentation

This document outlines the core backend features and modules of the system, based on the Supabase PostgreSQL schema and RPC functions. It provides a high-level overview of the purpose, table structures, and key Remote Procedure Calls (RPCs) for each feature area.

---

## 1. Authentication, Tenants & Memberships
**Purpose:** 
Handles user authentication, multi-tenancy, and role-based access control (RBAC). It ensures users can only access data for the tenant (organization) they belong to.

**Core Structure:**
*   `profiles`: Base user information tied to Supabase Auth.
*   `tenants`: The organizations/workspaces within the system.
*   `memberships`: Links `profiles` to `tenants` and defines their role (e.g., admin, staff, viewer).
*   `modules` & `tenant_modules`: Defines which features/modules are enabled for a specific tenant.

**Key RPCs:**
*   `check_login_membership()`: Validates if the current user has a valid membership to access the system.
*   `is_superadmin()` / `is_tenant_admin(p_tenant_id)`: Checks elevated privileges.
*   `can_manage_membership()`: Validates if a user can invite or manage other members in a tenant.
*   `list_tenants_by_membership()`: Returns the tenants a user has access to.

---

## 2. Customers & Groups
**Purpose:**
Manages B2B/B2C customer profiles and segments them into groups for targeted pricing, visibility, and access control.

**Core Structure:**
*   `customer_groups`: Defines a segment of customers (e.g., VIP, Wholesalers).
*   `customer_group_members`: Maps a user/profile to a specific customer group.

**Key RPCs:**
*   `enforce_customer_group_member_email_unique_per_tenant()`: Ensures data integrity for customer emails within a single tenant.

---

## 3. Store & Products
**Purpose:**
The catalog management system. It handles products, categories, brands, and the storefront visibility rules (who can see what prices).

**Core Structure:**
*   `products`, `product_brands`, `product_categories`: Core catalog data.
*   `stores`: Storefront configurations.
*   `store_access`: Defines which customer groups have access to which stores and whether they can see prices.
*   `markets`, `vendors`: Manages geographical markets and product suppliers.

**Key RPCs:**
*   `list_store_products()`: Fetches the product catalog for the store, applying RLS and visibility rules.
*   `list_products_paginated()`: Backend admin function for managing large product catalogs.
*   `set_product_lookup_updated_at_timestamp()`: Trigger for caching/syncing product lookups.

---

## 4. Costing & Quotes (Product Based Costing)
**Purpose:**
A negotiation and quotation system allowing customers to request bulk pricing, vendors/staff to calculate costs (including cargo and surcharges), and finalizing prices before order placement.

**Core Structure:**
*   `costing_files` & `product_based_costing_files`: The main quote/costing request document.
*   `costing_file_items` & `product_based_costing_items`: Individual products requested within the costing file.
*   `costing_file_viewers`: Access control for external viewers.

**Key RPCs:**
*   `apply_costing_item_calculations()`: Automatically calculates final costs based on item rates, cargo, and manual overrides.
*   `calculate_costing_item_type_surcharge_gbp()`: Computes additional surcharges.
*   `update_costing_file_status()`: Transitions a quote (e.g., Draft -> Submitted -> In Review -> Offered).

---

## 5. Carts & Orders
**Purpose:**
The transactional engine of the application. Handles pre-checkout carts and finalized orders.

**Core Structure:**
*   `carts` & `cart_items`: Temporary storage for items selected by a customer.
*   `orders`: Finalized purchases, linked to a specific status (e.g., Processing, Placed).
*   `order_items`: Line items in an order, tracking requested quantities, final prices, and associated shipments.

**Key RPCs:**
*   `get_cart()` / `get_cart_details()`: Retrieves the current active cart and its items with full product details.
*   `has_active_tenant_membership()`: Validates cart actions against tenant access.
*   `bulk_update_order_item_offers()`: Allows staff to update offered prices across multiple order items at once.

---

## 6. Shipments & Inventory
**Purpose:**
Tracks the physical movement of goods from vendors to the warehouse and finally to the customer. Manages stock levels.

**Core Structure:**
*   `shipments` & `shipment_items`: Tracks batches of products being shipped.
*   `inventory_items` & `inventory_stocks`: The actual physical units available in the warehouse.
*   `inventory_movements`: Audit log of stock going in or out.
*   `batch_code_pc`, `product_sync_snapshots`: Used for physical barcode/batch tracking.

**Key RPCs:**
*   Various RLS policies handle inventory visibility, ensuring customers only see stock they are allowed to buy.

---

## 7. Invoicing & Payments
**Purpose:**
Financial tracking. Generates invoices for completed orders and tracks payments against those invoices, including split allocations.

**Core Structure:**
*   `invoices` & `invoice_items`: Formal requests for payment.
*   `billing_profiles`: Customer billing information.
*   `payments`: Records of money received.
*   `payment_allocations`: Links a single payment to one or multiple invoices.
*   `inventory_accounting_entries` & `invoice_accounting_payments`: Deep financial ledger linking inventory to revenue.

**Key RPCs:**
*   `add_payment_allocation()`: RPC to safely distribute a payment amount across specific invoices.

---

## 8. Investors
**Purpose:**
An internal module for tracking third-party capital invested into specific shipments or general stock, and calculating their balances.

**Core Structure:**
*   `investors`: Profiles for financial backers.
*   `investor_transactions` & `shipment_investments`: Logs of capital deployed into the business or specific shipments.
*   `investor_balances`: Aggregated table showing current available capital and total profits.

**Key RPCs:**
*   `refresh_investor_balance()`: Recalculates an investor's balance and profit margins based on their transactions and shipment outcomes.

---

## 9. Task Management
**Purpose:**
Provides a collaborative workspace for teams to track projects, modules, submodules, tasks, notes, discussions, bugs, and features with hierarchical grouping and comments.

**Core Structure:**
*   `items`: Hierarchical work items (projects, tasks, bugs, etc.) supporting priority, status, and accessibility control.
*   `item_assignees`: Tracks team members assigned to items.
*   `tags` & `item_tags`: Custom categorized labels per tenant.
*   `comments`: Threaded messaging logs for collaboration.
*   `item_permissions`: Scoped permissions (`owner`, `manager`, `editor`, `viewer`, `commenter`) for restricted items.
*   `activity_logs`: Auditable logs of item updates.

**Key RPCs:**
*   `get_effective_item_role(p_item_id, p_user_email)`: Resolves a user's permission level recursively checking parent hierarchies.
*   `list_items_paginated()`: Paginated item fetcher with filters for assignees, priorities, status, and type.
*   `get_item_details()`: Retrieves detailed item data including tags, comments, assignees, and history.
*   `global_search_tasks(p_query)`: Executes cross-tenant global search over titles, content, tags, and comments.
