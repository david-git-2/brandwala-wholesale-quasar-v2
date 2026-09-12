begin;

create or replace function public.list_my_notifications_paginated(
  p_tenant_id bigint,
  p_page integer default 1,
  p_page_size integer default 20,
  p_unread_only boolean default false,
  p_event_type text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_total_count bigint;
  v_unread_count bigint;
  v_total_pages integer;
  v_data jsonb;
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
  into v_total_count
  from public.notification_recipients r
  join public.notifications n on n.id = r.notification_id
  where r.user_id = v_user_id
    and public.notification_inbox_scope_matches(p_tenant_id, n.parent_tenant_id, n.operating_tenant_id)
    and (not p_unread_only or r.read_at is null)
    and (p_event_type is null or p_event_type = '' or n.event_type = p_event_type);

  select count(*)
  into v_unread_count
  from public.notification_recipients r
  join public.notifications n on n.id = r.notification_id
  where r.user_id = v_user_id
    and r.read_at is null
    and public.notification_inbox_scope_matches(p_tenant_id, n.parent_tenant_id, n.operating_tenant_id);

  select coalesce(jsonb_agg(row_to_json(x)::jsonb), '[]'::jsonb)
  into v_data
  from (
    select
      r.id as recipient_id,
      n.id as notification_id,
      r.read_at,
      (r.read_at is null) as is_unread,
      n.event_type,
      n.title,
      n.body,
      n.link_path,
      n.entity_type,
      n.entity_id,
      n.parent_tenant_id,
      n.operating_tenant_id,
      t.name as operating_tenant_name,
      n.created_at
    from public.notification_recipients r
    join public.notifications n on n.id = r.notification_id
    left join public.tenants t on t.id = n.operating_tenant_id
    where r.user_id = v_user_id
      and public.notification_inbox_scope_matches(p_tenant_id, n.parent_tenant_id, n.operating_tenant_id)
      and (not p_unread_only or r.read_at is null)
      and (p_event_type is null or p_event_type = '' or n.event_type = p_event_type)
    order by n.created_at desc, r.created_at desc
    limit v_page_size
    offset (v_page - 1) * v_page_size
  ) x;

  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::numeric / v_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total_count', v_total_count,
      'page', v_page,
      'page_size', v_page_size,
      'total_pages', v_total_pages,
      'unread_count', v_unread_count
    )
  );
end;
$$;

commit;
