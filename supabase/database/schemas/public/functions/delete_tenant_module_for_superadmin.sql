CREATE FUNCTION public.delete_tenant_module_for_superadmin (
  p_id bigint
)
  RETURNS TABLE (
    id         bigint,
    tenant_id  bigint,
    module_key text,
    is_active  boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_deleted public.tenant_modules%rowtype;
begin
  if not public.is_superadmin() then
    return;
  end if;

  delete from public.tenant_modules tm
  where tm.id = p_id
  returning * into v_deleted;

  if v_deleted.id is not null then
    delete from public.tenant_module_submodules tms
    where tms.tenant_id = v_deleted.tenant_id
      and tms.parent_module_key = v_deleted.module_key;
  end if;

  return query
  select
    v_deleted.id,
    v_deleted.tenant_id,
    v_deleted.module_key,
    v_deleted.is_active,
    v_deleted.created_at,
    v_deleted.updated_at;
end;
$function$;

GRANT ALL ON FUNCTION public.delete_tenant_module_for_superadmin(bigint) TO anon;

GRANT ALL ON FUNCTION public.delete_tenant_module_for_superadmin(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.delete_tenant_module_for_superadmin(bigint) TO service_role;