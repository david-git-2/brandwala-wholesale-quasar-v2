-- Shop session uses the chosen customer group (header), not a silent first-row pick.

create or replace function public.current_selected_customer_group_id()
returns bigint
language sql
stable
security definer
set search_path to 'public'
as $$
  select nullif(current_setting('request.headers', true)::json->>'x-selected-customer-group-id', '')::bigint
$$;

revoke all on function public.current_selected_customer_group_id() from public;
grant execute on function public.current_selected_customer_group_id() to authenticated;

create or replace function public.current_customer_group_id(p_tenant_id bigint)
returns bigint
language sql
stable
security definer
set search_path to 'public'
as $$
  with candidates as (
    select distinct cg.id
    from public.customer_groups cg
    join public.customer_group_members cgm on cgm.customer_group_id = cg.id
    where p_tenant_id is not null
      and cg.is_active = true
      and cg.deleted_at is null
      and cgm.is_active = true
      and lower(trim(cgm.email)) = public.current_user_email()
      and coalesce(cg.parent_tenant_id, cg.tenant_id) = public.resolve_parent_tenant_id(p_tenant_id)
      and (
        p_tenant_id = coalesce(cg.parent_tenant_id, cg.tenant_id)
        or exists (
          select 1
          from public.shop_customer_group_access scga
          inner join public.shops s on s.id = scga.shop_id
          where scga.customer_group_id = cg.id
            and scga.status = true
            and s.tenant_id = p_tenant_id
            and s.is_active = true
            and s.deleted_at is null
        )
      )
  )
  select c.id
  from candidates c
  where c.id = public.current_selected_customer_group_id()
     or (
       public.current_selected_customer_group_id() is null
       and (select count(*) from candidates) = 1
     )
  limit 1;
$$;

create or replace function public.check_shop_login_access(
  p_email text,
  p_tenant_id bigint default null
)
returns table(
  has_match boolean,
  matched_role public.customer_group_role,
  member_id bigint,
  member_name text,
  member_email text,
  member_tenant_id bigint,
  customer_group_id bigint,
  customer_group_name text,
  member_is_active boolean,
  customer_group_is_active boolean,
  member_created_at timestamp with time zone,
  member_updated_at timestamp with time zone
)
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_email text;
begin
  v_email := lower(trim(coalesce(p_email, public.current_user_email(), '')));

  return query
  select
    true,
    cgm.role,
    cgm.id,
    coalesce(
      nullif(trim(cgm.name), ''),
      (select coalesce(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name') from auth.users u where u.email = v_email limit 1)
    ),
    lower(trim(cgm.email)),
    cg.tenant_id,
    cg.id,
    cg.name,
    cgm.is_active,
    cg.is_active,
    cgm.created_at,
    cgm.updated_at
  from public.customer_group_members cgm
  inner join public.customer_groups cg
    on cg.id = cgm.customer_group_id
  where lower(trim(cgm.email)) = v_email
    and cgm.is_active = true
    and cg.is_active = true
    and cg.deleted_at is null
    and (
      p_tenant_id is null
      or exists (
        select 1
        from public.shop_customer_group_access scga
        inner join public.shops s on s.id = scga.shop_id
        where scga.customer_group_id = cg.id
          and scga.status = true
          and s.tenant_id = p_tenant_id
          and s.is_active = true
          and s.deleted_at is null
          and coalesce(cg.parent_tenant_id, cg.tenant_id)
            = public.resolve_parent_tenant_id(p_tenant_id)
      )
    )
  order by
    cg.name asc,
    cg.id asc,
    case cgm.role
      when 'admin' then 1
      when 'manager' then 2
      when 'staff' then 3
      else 99
    end asc,
    cgm.id asc;
end;
$$;

create or replace function public.get_shop_bootstrap_context(
  p_email text default null,
  p_tenant_id bigint default null,
  p_customer_group_member_id bigint default null
)
returns table(
  member_id bigint,
  member_name text,
  member_email text,
  member_role public.customer_group_role,
  member_is_active boolean,
  customer_group_id bigint,
  customer_group_name text,
  customer_group_is_active boolean,
  customer_group_accent_color text,
  tenant_id bigint,
  tenant_name text,
  tenant_slug text,
  tenant_is_active boolean,
  active_module_keys text[],
  tenant_role_id bigint,
  is_admin boolean,
  effective_grants jsonb,
  permission_version bigint
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_email text;
  v_member record;
  v_grants jsonb;
  v_perm_version bigint;
begin
  v_email := lower(trim(coalesce(p_email, public.current_user_email())));

  if p_tenant_id is null or p_customer_group_member_id is null then
    return;
  end if;

  select
    cgm.id,
    coalesce(
      nullif(trim(cgm.name), ''),
      (select coalesce(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name') from auth.users u where u.email = v_email limit 1)
    ) as name,
    lower(trim(cgm.email)) as email,
    cgm.role,
    cgm.is_active,
    cgm.tenant_role_id,
    cg.id as customer_group_id,
    cg.name as customer_group_name,
    cg.is_active as customer_group_is_active,
    cg.accent_color as customer_group_accent_color,
    t.id as tenant_id,
    t.name as tenant_name,
    t.slug as tenant_slug,
    t.is_active as tenant_is_active,
    coalesce(tr.is_admin, cgm.role = 'admin', false) as is_admin
  into v_member
  from public.customer_group_members cgm
  inner join public.customer_groups cg on cg.id = cgm.customer_group_id
  inner join public.tenants t on t.id = p_tenant_id
  left join public.tenant_roles tr on tr.id = cgm.tenant_role_id
  where p_tenant_id is not null
    and lower(trim(cgm.email)) = v_email
    and cgm.is_active = true
    and cg.is_active = true
    and cg.deleted_at is null
    and t.is_active = true
    and cgm.id = p_customer_group_member_id
    and coalesce(cg.parent_tenant_id, cg.tenant_id) = public.resolve_parent_tenant_id(p_tenant_id)
    and exists (
      select 1
      from public.shop_customer_group_access scga
      inner join public.shops s on s.id = scga.shop_id
      where scga.customer_group_id = cg.id
        and scga.status = true
        and s.tenant_id = p_tenant_id
        and s.is_active = true
        and s.deleted_at is null
    )
  order by
    case cgm.role
      when 'admin' then 1
      when 'manager' then 2
      when 'staff' then 3
      else 99
    end,
    cgm.id asc
  limit 1;

  if v_member.id is null then
    return;
  end if;

  select coalesce(
    jsonb_agg(jsonb_build_object('module_key', module_key, 'action', action)),
    '[]'::jsonb
  )
  into v_grants
  from public.get_shop_effective_grants(v_member.tenant_id, v_member.id);

  select tpv.version into v_perm_version
  from public.tenant_permission_versions tpv
  where tpv.tenant_id = v_member.tenant_id;

  if v_perm_version is null then
    perform public.bump_tenant_permission_version(v_member.tenant_id);
    v_perm_version := 1;
  end if;

  return query
  select
    v_member.id as member_id,
    v_member.name as member_name,
    v_member.email as member_email,
    v_member.role as member_role,
    v_member.is_active as member_is_active,
    v_member.customer_group_id,
    v_member.customer_group_name,
    v_member.customer_group_is_active,
    v_member.customer_group_accent_color,
    v_member.tenant_id,
    v_member.tenant_name,
    v_member.tenant_slug,
    v_member.tenant_is_active,
    coalesce(public.get_active_module_keys_for_tenant(v_member.tenant_id), array[]::text[]) as active_module_keys,
    v_member.tenant_role_id,
    v_member.is_admin,
    v_grants as effective_grants,
    v_perm_version as permission_version;
end;
$$;

create or replace function public.get_shop_permissions_for_customer(p_shop_id bigint)
returns table(
  can_browse boolean,
  can_see_buy_price boolean,
  can_see_sell_price boolean,
  can_see_resell_minimum_price boolean,
  can_add_to_cart boolean,
  can_place_order boolean,
  can_negotiate boolean,
  can_view_quantity boolean,
  can_set_dropship_price boolean
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_shop_active boolean;
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_shop_allows_negotiate boolean;
begin
  select is_active, tenant_id, shop_type
  into v_shop_active, v_tenant_id, v_shop_type
  from public.shops
  where id = p_shop_id;

  if v_shop_active is not true then
    return query select false, false, false, false, false, false, false, false, false;
    return;
  end if;
  v_shop_allows_negotiate := v_shop_type = 'vendor_catalog';

  return query
  select
    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else coalesce(access.can_browse, profile.default_can_browse, false)
      end
    ), false) as can_browse,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else public.resolve_shop_can_see_buy_price(
        v_shop_type,
        access.can_see_buy_price,
        access.can_see_sell_price,
        profile.default_can_see_buy_price,
        profile.default_can_see_sell_price
      )
      end
    ), false) as can_see_buy_price,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else
        case when v_shop_type = 'dropship' then true
        else coalesce(access.can_see_sell_price, profile.default_can_see_sell_price, false)
        end
      end
    ), false) as can_see_sell_price,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else coalesce(access.can_see_resell_minimum_price, profile.default_can_see_resell_minimum_price, false)
      end
    ), false) as can_see_resell_minimum_price,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else coalesce(access.can_add_to_cart, profile.default_can_add_to_cart, false)
      end
    ), false) as can_add_to_cart,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else coalesce(access.can_place_order, profile.default_can_place_order, false)
      end
    ), false) as can_place_order,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else coalesce(access.can_negotiate, profile.default_can_negotiate, false)
      end
    ) and v_shop_allows_negotiate, false) as can_negotiate,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else coalesce(access.can_view_quantity, profile.default_can_view_quantity, false)
      end
    ), false) as can_view_quantity,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else
        case when v_shop_type = 'dropship' then true
        else coalesce(access.can_set_dropship_price, profile.default_can_set_dropship_price, false)
        end
      end
    ), false) as can_set_dropship_price
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  join public.shop_customer_group_access access on access.customer_group_id = cg.id
  left join public.customer_group_shop_profiles profile
    on profile.customer_group_id = cg.id and profile.tenant_id = v_tenant_id
  where access.shop_id = p_shop_id
    and cg.id = public.current_customer_group_id(v_tenant_id)
    and cg.is_active = true
    and cg.deleted_at is null
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email()
    and coalesce(cg.parent_tenant_id, cg.tenant_id) = public.resolve_parent_tenant_id(v_tenant_id);
end;
$$;
