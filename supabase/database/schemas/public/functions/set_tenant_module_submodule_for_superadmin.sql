CREATE FUNCTION public.set_tenant_module_submodule_for_superadmin (
  p_tenant_id         bigint,
  p_parent_module_key text,
  p_submodule_key     text,
  p_is_enabled        boolean
)
  RETURNS TABLE (
    id                bigint,
    tenant_id         bigint,
    parent_module_key text,
    submodule_key     text,
    is_enabled        boolean,
    created_at        timestamp with time zone,
    updated_at        timestamp with time zone
  )
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  with permission as (
    select public.is_superadmin() as allowed
  ),
  upserted as (
    insert into public.tenant_module_submodules (
      tenant_id,
      parent_module_key,
      submodule_key,
      is_enabled
    )
    select
      p_tenant_id,
      lower(trim(p_parent_module_key)),
      lower(trim(p_submodule_key)),
      coalesce(p_is_enabled, true)
    from permission
    where allowed
      and p_tenant_id is not null
      and exists (
        select 1
        from public.tenant_modules tm
        where tm.tenant_id = p_tenant_id
          and tm.module_key = lower(trim(p_parent_module_key))
          and tm.is_active = true
      )
    on conflict (tenant_id, submodule_key) do update
    set
      parent_module_key = excluded.parent_module_key,
      is_enabled = excluded.is_enabled
    returning
      id,
      tenant_id,
      parent_module_key,
      submodule_key,
      is_enabled,
      created_at,
      updated_at
  )
  select
    id,
    tenant_id,
    parent_module_key,
    submodule_key,
    is_enabled,
    created_at,
    updated_at
  from upserted;
$function$;

GRANT ALL ON FUNCTION public.set_tenant_module_submodule_for_superadmin(bigint, text, text, boolean) TO anon;

GRANT ALL ON FUNCTION public.set_tenant_module_submodule_for_superadmin(bigint, text, text, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.set_tenant_module_submodule_for_superadmin(bigint, text, text, boolean) TO service_role;