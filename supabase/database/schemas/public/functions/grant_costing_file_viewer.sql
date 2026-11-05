CREATE FUNCTION public.grant_costing_file_viewer (
  p_costing_file_id bigint,
  p_membership_id   bigint
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
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  with target_file as (
    select cf.id, cf.tenant_id
    from public.costing_files cf
    where cf.id = p_costing_file_id
      and public.can_manage_costing_file_viewers(cf.tenant_id)
  ),
  target_viewer as (
    select m.id, m.email, m.role, m.is_active
    from public.memberships m
    inner join target_file tf
      on true
    where m.id = p_membership_id
      and m.tenant_id = tf.tenant_id
      and m.role = 'viewer'
      and m.is_active = true
  ),
  inserted as (
    insert into public.costing_file_viewers (
      costing_file_id,
      membership_id
    )
    select
      tf.id,
      tv.id
    from target_file tf
    cross join target_viewer tv
    on conflict (costing_file_id, membership_id) do update
      set updated_at = now()
    returning
      id as costing_file_viewer_id,
      costing_file_id,
      membership_id,
      created_at,
      updated_at
  )
  select
    i.costing_file_viewer_id,
    i.costing_file_id,
    i.membership_id,
    tv.email as name,
    tv.email,
    tv.role,
    tv.is_active,
    i.created_at,
    i.updated_at
  from inserted i
  inner join target_viewer tv
    on tv.id = i.membership_id;
$function$;

GRANT ALL ON FUNCTION public.grant_costing_file_viewer(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.grant_costing_file_viewer(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.grant_costing_file_viewer(bigint, bigint) TO service_role;