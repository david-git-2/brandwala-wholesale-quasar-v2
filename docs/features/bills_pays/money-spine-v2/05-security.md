# Money spine v2 — security

Privileges, assert, RLS, and DEFINER rules. Writers: [02-actions.md](02-actions.md). Invariants: [00-overview.md](00-overview.md).

## Privilege matrix (EXECUTE)

| RPC | `anon` | `authenticated` | `service_role` | Action(s) |
| :--- | :---: | :---: | :---: | :--- |
| `rpc_deposit` | deny | grant + `deposit` | grant | deposit |
| `rpc_withdraw` | deny | grant + `withdraw` | grant | withdraw |
| `rpc_transfer_same_profile` | deny | grant + `withdraw` on from pot | grant | withdraw |
| `rpc_transfer_p2p` | deny | grant + `transfer` + profile spend | grant | transfer |
| `rpc_pay_bills` / `rpc_pay_bill` | deny | grant + `pay` | grant | pay |
| `rpc_apply_document_settlement` | deny | grant + `pay` | grant | pay |
| `rpc_void_document_settlement` | deny | grant + `void` | grant | void |
| `rpc_void_pays` | deny | grant + `void` | grant | void |
| `rpc_update_pays` | deny | grant + `pay` | grant | pay |
| `rpc_create_bill` | deny | grant + module bill create | grant | — |
| `rpc_issue_bill` | deny | grant + issue | grant | — |
| `rpc_void_bill` | deny | grant + `void` | grant | void |
| `rpc_write_off_bill` | deny | grant + `write_off` | grant | write_off |
| `rpc_provision_*` | deny | grant admin | grant | — |
| `rpc_allocate_invoice_no` | deny | **deny** | internal | — |
| Read RPCs + views | deny | grant SELECT path | grant | — |

Bootstrap:

```sql
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon, authenticated;
-- then GRANT only the 16 public write RPCs + read RPCs (see 02-actions §6)
```

`anon` must receive **no** EXECUTE on any `rpc_*` money function (TC-SEC).

## `assert_kernel_money_access`

```sql
CREATE OR REPLACE FUNCTION money_kernel.assert_kernel_money_access(
  p_tenant_id   bigint,
  p_action      text,
  p_profile_id  bigint DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF p_tenant_id IS NULL OR p_action IS NULL THEN
    RAISE EXCEPTION 'access_denied: invalid_arguments';
  END IF;

  IF v_uid IS NULL THEN
    IF current_setting('request.jwt.claim.role', true) = 'service_role' THEN
      RETURN;
    END IF;
    RAISE EXCEPTION 'access_denied: not_authenticated';
  END IF;

  -- Uniform denial (no tenant enumeration via not_found)
  IF NOT membership_has_money_action(v_uid, p_tenant_id, p_action) THEN
    RAISE EXCEPTION 'access_denied: tenant % action %', p_tenant_id, p_action;
  END IF;

  IF p_profile_id IS NOT NULL
     AND p_action IN ('withdraw', 'transfer', 'pay')
     AND NOT profile_spend_allowed(v_uid, p_tenant_id, p_profile_id) THEN
    RAISE EXCEPTION 'access_denied: profile %', p_profile_id;
  END IF;
END;
$$;
```

| Action | Typical grant |
| :--- | :--- |
| `deposit` | treasury / cashier |
| `withdraw` | treasury / owner of from profile |
| `transfer` | treasury + explicit transfer |
| `pay` | AR/AP desk |
| `void` | supervisor |
| `write_off` | finance lead |
| `fx_override` | finance admin |

Map to live `has_module_action()` / `membership_has_module_action()` at implement time.

## RLS (SELECT)

Helper (single eval per statement):

```sql
CREATE OR REPLACE FUNCTION public.auth_tenant_id()
RETURNS bigint
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.tenant_id', true), '')::bigint;
$$;
```

Pattern: `(select auth_tenant_id())` in policies. Multi-tenant users: `tenant_memberships` drives `auth_tenant_ids()` set variant for reads.

```sql
ALTER TABLE money_kernel.bills ENABLE ROW LEVEL SECURITY;

CREATE POLICY bills_select ON money_kernel.bills
  FOR SELECT TO authenticated
  USING (
    tenant_id = (select auth_tenant_id())
    OR issued_by_tenant_id = (select auth_tenant_id())
  );
```

| Table | USING |
| :--- | :--- |
| `bills` | `tenant_id` or `issued_by_tenant_id` = auth tenant |
| `bill_lines` | `tenant_id = auth` OR exists bill visible to issuer child |
| `bill_events` | same as lines (denormalized `tenant_id` preferred) |
| `cashbook_*`, `profiles` | `tenant_id = (select auth_tenant_id())` |
| `pays`, `bill_settlements` | no direct SELECT for `authenticated` (RPC only) |

Cross-tenant **writes** (`issued_by_tenant_id ≠ tenant_id`): enforced in RPC + assert, not RLS alone.

## DEFINER rules

1. Every `SECURITY DEFINER` function: `SET search_path = money_kernel, pg_temp`.
2. Every query in a writer must include `tenant_id = p_tenant_id` (or equivalent join) on **each** table touched.
3. CI lint (pgTAP or `supabase db lint` custom): parse DEFINER bodies; flag FROM/JOIN without tenant predicate.
4. No `authenticated` INSERT/UPDATE/DELETE on kernel tables; REVOKE + triggers G1.

## Schema exposure

- Tables in `money_kernel` — not in Supabase API exposure list.
- `public` exposes thin `rpc_*` wrappers calling kernel implementations.
