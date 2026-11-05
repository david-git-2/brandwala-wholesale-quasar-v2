CREATE FUNCTION public.get_active_module_keys_for_tenant (
  p_tenant_id bigint
)
  RETURNS text[]
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.get_active_module_keys_for_tenant(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_active_module_keys_for_tenant(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_active_module_keys_for_tenant(bigint) TO service_role;