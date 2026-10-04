# Tenant auth & access control — spec

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/tenant_auth/spec.md` + [00-gaps](00-gaps.md) |
| UI | `auth/`, `tenant/`, `membership/`, `access_control/` |
| SQL | Stubs `tenants/`, `permissions/`; live mostly `public.sql` |
| Access | Scopes `platform` \| `app` \| `shop` \| `investor`; `effectiveGrants` |

## Where to look

| Need | Path |
| :--- | :--- |
| Memberships, tenants | Grep in `public.sql` |
| Grants | `has_module_action()`, `effectiveGrants` in web auth store |
| Routes | Grep `/platform/`, `/app/`, `/shop/`, `/investor/` in router |

## Scope

| | |
| :--- | :--- |
| Surfaces | All four logins |
| In | OAuth, memberships, grants, tenant hierarchy, workspace switch |
| Out | Domain ERP screens (those packs own their pages) |

See [scopes](../../architecture/scopes.md).

## Personas

| Role | Actions |
| :--- | :--- |
| Platform superadmin | Provision tenants, domains, flags |
| Company owner / admin | Staff, invites, grants |
| Staff | RBAC `view`/`create`/`edit`/`delete`/`manage` |
| Shop customer | Buyer portal |
| Investor | Portal via `memberships.role = investor` + `investor_id` — [investor_capital spec](../investor_capital/spec.md) |

## Stories

### US-1: Company vs brand hierarchy
- Parent company + one-level child brands; books at company.
  - [ ] `parent_id` null = company; brands point to company.
  - [ ] Workspace switcher: companies only; `list_child_tenant_refs`.

### US-2: Four URL scopes
- [ ] `/platform/*` — superadmin (not `/superadmin/*`).
- [ ] `/:slug/app/*` — ERP.
- [ ] `/:slug/shop/*` — storefront.
- [ ] `/:slug/investor/*` — capital portal.

### US-3: Three-layer RBAC
- Module enabled → admin bypass → explicit action grants.
  - [ ] UI hides nav/actions without grant.
