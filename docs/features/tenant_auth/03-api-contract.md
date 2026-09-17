# Tenant Auth & Access Control — API Contract & RPC Signatures

> **RPC Functions Target**: Multi-Tenant Membership, Hierarchy Resolution & RBAC Checks  
> **Security Level**: `SECURITY DEFINER`

---

## 1. Hierarchy Resolution RPC: `list_child_tenant_refs`

Batched RPC returning child brand references for a set of parent company IDs, optimizing layout bootstrap to a single network call.

### Signature
```sql
create or replace function public.list_child_tenant_refs(
  p_parent_tenant_ids uuid[]
)
returns table (
  id uuid,
  parent_id uuid,
  name text,
  slug text
)
language plpgsql security definer stable;
```

---

## 2. Staff Membership Listing RPC: `list_tenants_by_membership`

Returns all companies and brands accessible to the authenticated user with assigned roles and module actions.

### Signature
```sql
create or replace function public.list_tenants_by_membership()
returns table (
  tenant_id uuid,
  tenant_name text,
  tenant_slug text,
  parent_id uuid,
  role public.membership_role,
  is_active boolean,
  actions jsonb
)
language plpgsql security definer;
```

---

## 3. Operational Data Reset RPC (Dev & Staging Utility)

Cleanses operational mock transactions while preserving master data (users, tenant config, products).

### Signature
```sql
create or replace function public.reset_tenant_operational_data(
  p_tenant_id uuid,
  p_confirmation_token text
)
returns jsonb
language plpgsql security definer;
```
