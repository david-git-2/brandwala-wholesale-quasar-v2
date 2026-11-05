CREATE FUNCTION public.mark_all_my_notifications_read (
  p_tenant_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_user_id uuid := auth.uid();
  v_updated_count bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  if not (
    public.is_superadmin()
    or public.has_active_tenant_membership(p_tenant_id)
    or public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(p_tenant_id))
    or public.has_shop_notification_access(p_tenant_id)
  ) then
    raise exception 'Permission denied for tenant %', p_tenant_id;
  end if;

  with updated as (
    update public.notification_recipients r
    set read_at = now()
    from public.notifications n
    where n.id = r.notification_id
      and r.user_id = v_user_id
      and r.read_at is null
      and public.notification_inbox_scope_matches(p_tenant_id, n.parent_tenant_id, n.operating_tenant_id)
    returning r.id
  )
  select count(*) into v_updated_count from updated;

  return jsonb_build_object(
    'success', true,
    'updated_count', coalesce(v_updated_count, 0)
  );
end;
$function$;

GRANT ALL ON FUNCTION public.mark_all_my_notifications_read(bigint) TO anon;

GRANT ALL ON FUNCTION public.mark_all_my_notifications_read(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.mark_all_my_notifications_read(bigint) TO service_role;