CREATE FUNCTION public.list_costing_file_viewers (
  p_costing_file_id bigint
)
  RETURNS TABLE (
    costing_file_viewer_id bigint,
    costing_file_id        bigint,
    membership_id          bigint,
    name                   text,
    email                  text,
    role                   public.app_role,
    is_active              boolean,
    created_at             timestamp with time zone,
    updated_at             timestamp with time zone
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    cfv.id as costing_file_viewer_id,
    cfv.costing_file_id,
    cfv.membership_id,
    m.email as name,
    m.email,
    m.role,
    m.is_active,
    cfv.created_at,
    cfv.updated_at
  from public.costing_file_viewers cfv
  inner join public.memberships m
    on m.id = cfv.membership_id
  where cfv.costing_file_id = p_costing_file_id
    and exists (
      select 1
      from public.costing_files cf
      where cf.id = p_costing_file_id
        and public.can_manage_costing_file_viewers(cf.tenant_id)
    )
  order by cfv.id asc;
$function$;

GRANT ALL ON FUNCTION public.list_costing_file_viewers(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_costing_file_viewers(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_costing_file_viewers(bigint) TO service_role;