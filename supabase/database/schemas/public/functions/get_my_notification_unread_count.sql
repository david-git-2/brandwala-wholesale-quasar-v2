CREATE FUNCTION public.get_my_notification_unread_count (
  p_tenant_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_user_id uuid := auth.uid();
  v_unread_count bigint;
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

  select count(*)
  into v_unread_count
  from public.notification_recipients r
  join public.notifications n on n.id = r.notification_id
  where r.user_id = v_user_id
    and r.read_at is null
    and public.notification_inbox_scope_matches(p_tenant_id, n.parent_tenant_id, n.operating_tenant_id);

  return jsonb_build_object('unread_count', coalesce(v_unread_count, 0));
end;
$function$;

GRANT ALL ON FUNCTION public.get_my_notification_unread_count(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_my_notification_unread_count(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_my_notification_unread_count(bigint) TO service_role;