# Tenant Auth & Access Control — Product Requirements Document (PRD)

> **Module**: Multi-Tenancy, Hierarchy Governance, OAuth & Role-Based Access Control (RBAC)  
> **Status**: Approved & Active  
> **Target Release**: v2.4.0  
> **Target Audience**: Platform Superadmins, Company Owners, IT Security Leads, Staff Administrators

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/tenant_auth/` |
| UI | `web/src/modules/auth/`, `tenant/`, `membership/`, `access_control/` |
| SQL | Stubs `tenants/`, `permissions/`; live mostly `public.sql` |
| Access | Scopes `platform` \| `app` \| `shop` \| `investor`; grants via `effectiveGrants` |

## Scope

| | |
| :--- | :--- |
| Surfaces | All four logins |
| In | OAuth, memberships, grants, tenant hierarchy, workspace switch |
| Out | Domain ERP screens (those packs own their pages) |

See [scopes](../../architecture/scopes.md).

---

## 1. Executive Summary

The **Tenant Auth & Access Control** foundation defines TradeFlow BD's organizational structure (Parent Company vs Child Brand), the 4 isolated application URL scopes (`platform`, `app`, `shop`, `investor`), OAuth authentication, and granular 3-layer RBAC permissions (`tenant_modules` $\rightarrow$ `role` $\rightarrow$ `module_actions`).

It ensures complete data isolation across multi-tenant boundaries while providing single-session workspace switching for company owners and automated child-tenant hierarchy resolution.

---

## 2. User Personas & Permissions

| Role | Access Level | Permitted Actions |
| :--- | :--- | :--- |
| **Platform Superadmin** | Global Access | Provision new parent companies, configure custom domains, toggle platform feature flags. |
| **Company Owner / Admin** | Company Superuser | Full access to company workspace, manage staff memberships, invite users, assign granular action grants. |
| **Staff Member** | Granular RBAC | Access permitted modules (`view`, `create`, `edit`, `delete`, `manage`) as defined in `module_actions`. |
| **Storefront Customer** | Shop Scope | Log in to buyer portal, browse authorized storefronts, submit cart orders. |
| **Investor** | Investor Scope (`/:slug/investor/*`) | View capital accounts and yield performance. Login via `memberships.role = investor` and `memberships.investor_id` → partner profile; not staff RBAC. See [investor_capital](../investor_capital/01-prd.md). |

---

## 3. User Stories & Acceptance Criteria

### US-1: Company vs Brand Hierarchy Model
- **As a** Company Owner  
- **I want to** operate my business from the Parent Company workspace while creating Sister Concern Brands for selling channels  
- **So that** physical warehouse stock and accounting books remain consolidated at the company level.

#### Acceptance Criteria
- [ ] Hierarchy is strictly 1-level deep (`parent_id = NULL` for Companies, `parent_id = company.id` for Brands).
- [ ] Top bar workspace switcher lists **Companies only**; operational staff work from the company context.
- [ ] System automatically hydrates child brand refs via batch RPC `list_child_tenant_refs`.

### US-2: 4 Application URL Scopes
- **As a** Platform Operator  
- **I want** clean separation across URL scopes (`/superadmin/*`, `/:slug/app/*`, `/:slug/shop/*`, `/:slug/investor/*`)  
- **So that** staff, storefront buyers, investors, and superadmins operate in purpose-built layouts.

#### Acceptance Criteria
- [ ] `/superadmin/*`: Platform provisioning and tenant administration.
- [ ] `/:slug/app/*`: Backoffice ERP for operations and finance.
- [ ] `/:slug/shop/*`: Reseller and B2B storefront commerce.
- [ ] `/:slug/investor/*`: Investor capital statements and yield metrics.

### US-3: 3-Layer Granular RBAC Evaluation
- **As a** Security Officer  
- **I want** access control evaluated through 3 sequential gates (Module Enabled $\rightarrow$ Admin Superuser $\rightarrow$ Explicit Action Grants)  
- **So that** staff members only see and execute authorized actions.

#### Acceptance Criteria
- [ ] Action grants support `view`, `create`, `edit`, `delete`, and `manage`.
- [ ] UI navigation menus and action buttons hide dynamically when permissions are absent.

---

## 4. UI Layout & Wireframe

### Staff Members & Permission Management

```text
+----------------------------------------------------------------------------------------------------+
| Breadcrumbs: App > Settings > Staff & Access Control                                               |
+----------------------------------------------------------------------------------------------------+
| [ Search staff member... ] [ Role: All v ]                                       [ + Invite Staff ]|
+----------------------------------------------------------------------------------------------------+
| NAME / EMAIL           | ROLE     | PERMITTED MODULES                     | STATUS   | ACTIONS     |
|------------------------+----------+---------------------------------------+----------+-------------|
| Rafiq Ahmed (Admin)    | Admin    | Full Company Access (All Modules)     | Active   | [Manage]    |
| Nusrat Jahan (Staff)   | Staff    | Procurement (View, Edit), Invoices(Cr)| Active   | [Edit Roles]|
| Tanvir Khan (Staff)    | Staff    | Sales Invoices (View, Create, Collect)| Active   | [Edit Roles]|
+----------------------------------------------------------------------------------------------------+
```
