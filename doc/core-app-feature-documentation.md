# TradeFlow BD Core App Feature Documentation

## 1. Purpose
TradeFlow BD is a multi-tenant wholesale operations platform. It supports internal operations (admin/staff/viewer) and customer-side commerce in one system, with strict tenant isolation and role-based access.

## 2. Access Scopes
The application is divided into three scopes, each with a dedicated URL prefix and access model.

### Platform (`/platform`)
Used by superadmins to manage the full system.
- Create and manage tenants
- Assign tenant admins
- Control module/feature enablement per tenant

### App (`/app`)
Used by internal tenant users.
- Tenant admins manage day-to-day operations
- Staff and viewers work within granted permissions
- Internal features include operations like products, costing, inventory, shipment, orders, and accounting modules

### Shop (`/shop`)
Used by customer-side users.
- Customer group members access stores/products assigned to their group
- Place orders and continue customer workflow based on group-level permissions

## 3. Core Architecture Rules

### Multi-Tenant Data Isolation
- Every major business table is tenant-scoped.
- Tenant separation is enforced through tenant context + Supabase Row Level Security (RLS).
- Users only see data for authorized tenants.

### Tenant Identity and Routing
- Each tenant has a unique identity (slug/name) used in tenant-specific flows.
- Routes are scope-based (`/platform`, `/app`, `/shop`) and permission-checked.

## 4. Membership (Internal Users)
Internal access is controlled by the membership model.

### Membership Model
- Internal users are stored as tenant memberships.
- Typical roles: `admin`, `staff`, `viewer` (plus global `superadmin` in platform scope).

### Membership Responsibilities
- Superadmin can create tenants and assign tenant admins.
- Tenant admin can assign/manage internal members for that tenant.
- Staff/viewer permissions are limited by role and enabled modules.

### Key Rule
Internal authorization must come from membership data, not from customer-group membership.

## 5. Customer Group and Customer Group Members
Customer-side access is a separate authorization system and must remain independent from internal membership.

### Customer Group
- A customer group belongs to a tenant.
- Customer groups organize external/customer-side accounts.
- Business flows like store access and order context are tied to customer groups.

### Customer Group Member
- A customer group member is a customer-side user attached to a customer group.
- Shop authorization is resolved using customer-group member context.
- A customer-side user only sees resources allowed for their customer group.

### Data Integrity Rules
- Customer-side access checks must be tenant-aware.
- Customer-group and membership authorization should not be mixed.
- Email uniqueness and membership constraints are enforced by backend rules/migrations.

## 6. Module-Based Feature Control
- Features are enabled/disabled per tenant through module configuration.
- UI navigation and backend access should both respect module permissions.
- Adding new features should always follow tenant + scope + role checks.

## 7. Practical Access Summary
- `platform`: superadmin-only management scope
- `app`: internal tenant operations scope via memberships
- `shop`: customer operations scope via customer-group members

## 8. Implementation Guardrails
When adding or updating features, always verify:
1. Tenant scoping is present on data and API paths.
2. Correct actor model is used (`membership` vs `customer_group_member`).
3. RLS/policies align with the intended scope.
4. Route-level and UI-level permission checks match backend rules.
5. Customer-side and internal authorization remain separated.
