# Scopes

Four **login surfaces** (not job titles).

| Scope | Who | Does |
| --- | --- | --- |
| platform | Superadmin | Tenants, module catalog, global reference |
| app | Tenant staff | ERP desks; grants via effectiveGrants |
| shop | Buyer / reseller | Storefront, cart, orders |
| investor | Capital partner | Read-only statements; no withdraw |

Shop and investor do not get warehouse bins, landed-cost lock, or platform tenant provision.

Kernel map (tenants, grants, RBAC, hierarchy): [Kernels → Access kernel](/docs/kernels#access-kernel).
