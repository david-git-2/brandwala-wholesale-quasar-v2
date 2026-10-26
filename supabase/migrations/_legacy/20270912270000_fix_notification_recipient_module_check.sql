begin;

-- Recipient resolution must check each staff member's grants, not auth.uid() / current_user_email()
-- (shop customers placing orders have no app membership grants).

create or replace function public.is_network_owner_for_email(
  p_email text,
  p_tenant_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = public.resolve_parent_tenant_id(p_tenant_id)
      and lower(trim(m.email)) = lower(trim(coalesce(p_email, '')))
      and m.role = 'owner'::public.app_role
      and m.is_active = true
  );
$$;

create or replace function public.membership_has_module_action_for_email(
  p_email text,
  p_tenant_id bigint,
  p_module_key text,
  p_action text
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
  v_member_id bigint;
  v_tenant_role_id bigint;
  v_role_is_admin boolean;
  v_member_role public.app_role;
  v_override_effect text;
  v_role_allowed boolean;
begin
  if v_email = '' or p_tenant_id is null or p_module_key is null then
    return false;
  end if;

  if public.is_network_owner_for_email(p_email, p_tenant_id) then
    return true;
  end if;

  if not (p_module_key = any(public.get_active_module_keys_for_tenant(p_tenant_id))) then
    return false;
  end if;

  select m.id, m.tenant_role_id, tr.is_admin, m.role
  into v_member_id, v_tenant_role_id, v_role_is_admin, v_member_role
  from public.memberships m
  left join public.tenant_roles tr on tr.id = m.tenant_role_id
  where m.tenant_id = p_tenant_id
    and lower(trim(m.email)) = v_email
    and m.is_active = true;

  if v_member_id is null then
    return false;
  end if;

  if v_member_role in ('owner'::public.app_role, 'manager'::public.app_role)
     or coalesce(v_role_is_admin, false) = true then
    return true;
  end if;

  select effect
  into v_override_effect
  from public.membership_grants
  where membership_id = v_member_id
    and module_key = p_module_key
    and action = p_action;

  if v_override_effect = 'deny' then
    return false;
  elsif v_override_effect = 'allow' then
    return true;
  end if;

  select allowed
  into v_role_allowed
  from public.tenant_role_grants
  where tenant_role_id = v_tenant_role_id
    and module_key = p_module_key
    and action = p_action;

  return coalesce(v_role_allowed, false);
end;
$$;

create or replace function public.resolve_notification_recipient_user_ids(
  p_parent_tenant_id bigint,
  p_operating_tenant_id bigint,
  p_audience public.notification_audience,
  p_recipient_user_ids uuid[] default null,
  p_module_key text default null,
  p_action text default 'view'
)
returns uuid[]
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user_ids uuid[];
begin
  if p_audience = 'assignee_only' then
    if p_recipient_user_ids is null or cardinality(p_recipient_user_ids) = 0 then
      return array[]::uuid[];
    end if;

    select coalesce(array_agg(distinct u.user_id), array[]::uuid[])
    into v_user_ids
    from unnest(p_recipient_user_ids) as input(user_id)
    join auth.users u on u.id = input.user_id
    where input.user_id is not null;

    return coalesce(v_user_ids, array[]::uuid[]);
  end if;

  if p_audience = 'child_only' and p_operating_tenant_id is null then
    return array[]::uuid[];
  end if;

  with pools as (
    select distinct
      u.id as user_id,
      m.tenant_id as membership_tenant_id,
      m.email as membership_email
    from public.memberships m
    join auth.users u on lower(trim(u.email)) = lower(trim(m.email))
    where m.is_active = true
      and (
        (
          p_audience in ('child_only', 'child_and_parent')
          and p_operating_tenant_id is not null
          and m.tenant_id = p_operating_tenant_id
        )
        or (
          p_audience in ('parent_only', 'child_and_parent')
          and m.tenant_id = p_parent_tenant_id
        )
        or (
          m.tenant_id = p_parent_tenant_id
          and m.role = 'owner'::public.app_role
        )
      )
  )
  select coalesce(array_agg(distinct p.user_id), array[]::uuid[])
  into v_user_ids
  from pools p
  where p_module_key is null
     or public.membership_has_module_action_for_email(
          p.membership_email,
          p.membership_tenant_id,
          p_module_key,
          p_action
        );

  return coalesce(v_user_ids, array[]::uuid[]);
end;
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
      p_module_key := 'shop_order_mgmt',
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

revoke all on function public.is_network_owner_for_email(text, bigint) from public;
revoke all on function public.membership_has_module_action_for_email(text, bigint, text, text) from public;

commit;
