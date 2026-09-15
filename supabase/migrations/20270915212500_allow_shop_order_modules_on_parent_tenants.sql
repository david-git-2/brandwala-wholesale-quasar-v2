-- Migration: Allow shop_order modules on parent tenants in get_active_module_keys_for_tenant

CREATE OR REPLACE FUNCTION "public"."get_active_module_keys_for_tenant"("p_tenant_id" bigint) RETURNS "text"[]
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with active_assignments as (
    select tm.module_key
    from public.tenant_modules tm
    inner join public.modules mo on mo.key = tm.module_key
    inner join public.tenants t on t.id = tm.tenant_id
    where p_tenant_id is not null
      and tm.tenant_id = p_tenant_id
      and t.is_active = true
      and tm.is_active = true
      and mo.is_active = true
  ),
  expanded_child_keys as (
    select child.key as module_key
    from active_assignments a
    inner join public.modules child
      on child.parent_module_key = a.module_key
    where child.is_active = true
      and not exists (
        select 1
        from public.tenant_module_submodules tms
        where tms.tenant_id = p_tenant_id
          and tms.submodule_key = child.key
          and tms.is_enabled = false
      )
  ),
  combined as (
    select module_key from active_assignments
    union
    select module_key from expanded_child_keys
  )
  select coalesce(
    array_agg(c.module_key order by c.module_key)
      filter (where c.module_key is not null),
    '{}'::text[]
  )
  from combined c;
$$;

ALTER FUNCTION "public"."get_active_module_keys_for_tenant"("p_tenant_id" bigint) OWNER TO "postgres";

-- Ensure modules are activated for parent tenant 15 if present
INSERT INTO public.tenant_modules (tenant_id, module_key, is_active)
VALUES 
  (15, 'shop_order', true),
  (15, 'shop_order_mgmt', true),
  (15, 'shop_config', true),
  (15, 'shop_pricing', true),
  (15, 'shop_category', true),
  (15, 'shop_shipping', true),
  (15, 'shop_permissions', true)
ON CONFLICT (tenant_id, module_key) 
DO UPDATE SET is_active = true, updated_at = now();

-- Bump permission version across tenants so cached client auth contexts refresh
SELECT public.bump_tenant_permission_version(t.id)
FROM public.tenants t
WHERE t.is_active = true;
