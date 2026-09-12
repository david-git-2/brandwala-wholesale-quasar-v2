begin;

-- ---------------------------------------------------------------------------
-- Shop customer notification access helpers
-- ---------------------------------------------------------------------------
create or replace function public.has_shop_notification_access(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.customer_group_members cgm
    join public.customer_groups cg on cg.id = cgm.customer_group_id
    where cgm.is_active = true
      and lower(trim(cgm.email)) = public.current_user_email()
      and public.resolve_parent_tenant_id(cg.tenant_id) = public.resolve_parent_tenant_id(p_tenant_id)
  );
$$;

create or replace function public.resolve_customer_group_notification_user_ids(p_customer_group_id bigint)
returns uuid[]
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(array_agg(distinct u.id), array[]::uuid[])
  from public.customer_group_members cgm
  join auth.users u on lower(trim(u.email)) = lower(trim(cgm.email))
  where cgm.customer_group_id = p_customer_group_id
    and cgm.is_active = true;
$$;

create or replace function public.notify_catalog_shop_order(
  p_order_id bigint,
  p_notify_staff boolean,
  p_notify_customer boolean,
  p_event_type text,
  p_title text,
  p_body text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_customer_user_ids uuid[];
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    return;
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog'::public.shop_type_enum then
    return;
  end if;

  if p_notify_staff then
    perform public.enqueue_notification(
      p_tenant_id := v_order.tenant_id,
      p_operating_tenant_id := v_order.tenant_id,
      p_audience := 'child_only',
      p_event_type := p_event_type,
      p_title := p_title,
      p_body := p_body,
      p_link_path := format('/app/shop/orders/%s', v_order.id),
      p_entity_type := 'shop_order',
      p_entity_id := v_order.id::text,
      p_module_key := 'shop_order',
      p_action := 'view'
    );
  end if;

  if p_notify_customer and v_order.customer_group_id is not null then
    v_customer_user_ids := public.resolve_customer_group_notification_user_ids(v_order.customer_group_id);

    if v_customer_user_ids is not null and cardinality(v_customer_user_ids) > 0 then
      perform public.enqueue_notification(
        p_tenant_id := v_order.tenant_id,
        p_operating_tenant_id := v_order.tenant_id,
        p_audience := 'assignee_only',
        p_event_type := p_event_type,
        p_title := p_title,
        p_body := p_body,
        p_link_path := format('/shop/orders/%s', v_order.id),
        p_entity_type := 'shop_order',
        p_entity_id := v_order.id::text,
        p_recipient_user_ids := v_customer_user_ids,
        p_module_key := null,
        p_action := 'view'
      );
    end if;
  end if;
end;
$$;

revoke all on function public.has_shop_notification_access(bigint) from public;
revoke all on function public.resolve_customer_group_notification_user_ids(bigint) from public;
revoke all on function public.notify_catalog_shop_order(bigint, boolean, boolean, text, text, text) from public;

-- ---------------------------------------------------------------------------
-- Allow shop customers to read their notification inbox
-- ---------------------------------------------------------------------------
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
      n.created_at
    from public.notification_recipients r
    join public.notifications n on n.id = r.notification_id
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

create or replace function public.get_my_notification_unread_count(
  p_tenant_id bigint
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
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
$$;

create or replace function public.mark_all_my_notifications_read(
  p_tenant_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
$$;

commit;
