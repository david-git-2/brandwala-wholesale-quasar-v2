-- Parent-owned customer groups on child shop tenants:
-- resolve group via books parent + shop_customer_group_access, not cg.tenant_id = shop tenant.

begin;

create or replace function public.current_customer_group_id(p_tenant_id bigint)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select cg.id
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
  order by
    case cgm.role
      when 'admin' then 1
      when 'manager' then 2
      when 'staff' then 3
      else 99
    end,
    cg.id
  limit 1;
$$;

create or replace function public.can_view_products_customer(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_customer_group_id(p_tenant_id) is not null;
$$;

create or replace function public.can_view_tenant_modules(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
    or public.current_customer_group_id(p_tenant_id) is not null;
$$;

create or replace function public.user_can_access_tenant_fetch(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_superadmin()
    or public.user_can_manage_parent_tenant(p_tenant_id)
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
    or public.current_customer_group_id(p_tenant_id) is not null;
$$;

create or replace function public.has_module_action(
  p_tenant_id bigint,
  p_module_key text,
  p_action text
)
returns boolean
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_has_app_action boolean;
  v_has_shop_action boolean;
  v_member_id bigint;
  v_tenant_role_id bigint;
  v_role_is_admin boolean;
  v_override_effect text;
  v_role_allowed boolean;
  v_shop_allowed boolean;
begin
  if public.is_superadmin() then
    return true;
  end if;

  if not (p_module_key = any(public.get_active_module_keys_for_tenant(p_tenant_id))) then
    return false;
  end if;

  if exists (
    select 1
    from public.tenants
    where id = p_tenant_id
      and parent_id is not null
  ) and p_module_key in (
    'global_shipment', 'global_stock', 'global_stock_type', 'procurement_stock',
    'shipment_reports', 'parent_dashboard', 'investor_reports',
    'investor_profiles', 'investor_capital_ledger', 'investor_shipment_share', 'investor_portal'
  ) then
    return false;
  end if;

  select
    exists(
      select 1 from public.module_actions ma
      where ma.module_key = p_module_key and ma.action = p_action
        and ma.scope in ('app', 'investor') and ma.is_active = true
    ),
    exists(
      select 1 from public.module_actions ma
      where ma.module_key = p_module_key and ma.action = p_action
        and ma.scope = 'shop' and ma.is_active = true
    )
  into v_has_app_action, v_has_shop_action;

  if v_has_app_action and exists (
    select 1 from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    select m.id, m.tenant_role_id, tr.is_admin
    into v_member_id, v_tenant_role_id, v_role_is_admin
    from public.memberships m
    left join public.tenant_roles tr on tr.id = m.tenant_role_id
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true;

    if coalesce(v_role_is_admin, false) = true then
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

  elsif v_has_shop_action and public.current_customer_group_id(p_tenant_id) is not null then
    if exists (
      select 1
      from public.customer_group_members cgm
      join public.customer_groups cg on cg.id = cgm.customer_group_id
      join public.tenant_roles tr on tr.id = cgm.tenant_role_id
      where cg.id = public.current_customer_group_id(p_tenant_id)
        and cg.is_active = true
        and cgm.is_active = true
        and lower(trim(cgm.email)) = public.current_user_email()
        and tr.is_admin = true
    ) then
      return true;
    end if;

    select
      coalesce(
        bool_or(case when g.effect = 'allow' then true else null end),
        bool_or(case when g.effect = 'deny' then false else null end),
        bool_or(rg.allowed)
      ) into v_shop_allowed
    from public.customer_group_members cgm
    join public.customer_groups cg on cg.id = cgm.customer_group_id
    left join public.customer_group_member_grants g
      on g.customer_group_member_id = cgm.id
      and g.module_key = p_module_key
      and g.action = p_action
    left join public.tenant_role_grants rg
      on rg.tenant_role_id = cgm.tenant_role_id
      and rg.module_key = p_module_key
      and rg.action = p_action
    where cg.id = public.current_customer_group_id(p_tenant_id)
      and cg.is_active = true
      and cgm.is_active = true
      and lower(trim(cgm.email)) = public.current_user_email();

    return coalesce(v_shop_allowed, false);
  end if;

  return false;
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
set search_path = public
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
    and cg.is_active = true
    and cg.deleted_at is null
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email()
    and coalesce(cg.parent_tenant_id, cg.tenant_id) = public.resolve_parent_tenant_id(v_tenant_id);
end;
$$;

create or replace function public.can_act_on_parent_tenant_stock(p_parent_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.has_active_tenant_membership(p_parent_tenant_id)
    or public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      inner join public.tenants t on t.id = m.tenant_id
      where t.parent_id = p_parent_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
    or exists (
      select 1
      from public.customer_group_members cgm
      inner join public.customer_groups cg on cg.id = cgm.customer_group_id
      inner join public.shop_customer_group_access scga on scga.customer_group_id = cg.id
      inner join public.shops s on s.id = scga.shop_id
      where public.resolve_parent_tenant_id(s.tenant_id) = p_parent_tenant_id
        and coalesce(cg.parent_tenant_id, cg.tenant_id) = p_parent_tenant_id
        and lower(trim(cgm.email)) = public.current_user_email()
        and cgm.is_active = true
        and cg.is_active = true
        and scga.status = true
        and s.is_active = true
        and s.deleted_at is null
    )
    or exists (
      select 1
      from public.shops s
      join lateral public.get_shop_permissions_for_customer(s.id) perms on true
      where public.resolve_parent_tenant_id(s.tenant_id) = p_parent_tenant_id
        and s.is_active = true
        and s.deleted_at is null
        and coalesce(perms.can_place_order, false)
    );
$$;

create or replace function public.can_access_demand_bucket_profile(
  p_tenant_id bigint,
  p_billing_profile_id bigint,
  p_staff_only boolean default false
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_profile record;
  v_is_parent boolean;
begin
  if p_tenant_id is null or p_billing_profile_id is null then
    return false;
  end if;

  select bp.id, bp.tenant_id, bp.customer_group_id
  into v_profile
  from public.billing_profiles bp
  where bp.id = p_billing_profile_id;

  if not found then
    return false;
  end if;

  if v_profile.tenant_id <> p_tenant_id then
    if not exists (
      select 1
      from public.tenants t
      where t.id = v_profile.tenant_id
        and t.parent_id = p_tenant_id
    ) then
      return false;
    end if;
  end if;

  select (t.parent_id is null) into v_is_parent
  from public.tenants t
  where t.id = p_tenant_id;

  if coalesce(v_is_parent, false) then
    if public.user_can_manage_parent_tenant(p_tenant_id) then
      return true;
    end if;
  elsif public.is_tenant_staff(p_tenant_id)
     or public.is_tenant_staff(v_profile.tenant_id) then
    return true;
  end if;

  if p_staff_only then
    return false;
  end if;

  if v_profile.customer_group_id is not null
     and public.is_customer_group_member(v_profile.customer_group_id) then
    return exists (
      select 1
      from public.customer_groups cg
      where cg.id = v_profile.customer_group_id
        and cg.is_active = true
        and cg.deleted_at is null
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
    );
  end if;

  return false;
end;
$$;

create or replace function public.get_recipient_profile_by_phone(
  p_tenant_id bigint,
  p_phone text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_phone text;
  v_row public.recipient_profiles%rowtype;
  v_can_access boolean;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  v_can_access := public.is_tenant_staff(p_tenant_id)
    or public.current_customer_group_id(p_tenant_id) is not null;

  if not v_can_access then
    raise exception 'access denied';
  end if;

  begin
    v_phone := public.normalize_bd_mobile(p_phone);
  exception when others then
    return null;
  end;

  select * into v_row
  from public.recipient_profiles
  where coalesce(parent_tenant_id, tenant_id) = public.resolve_parent_tenant_id(p_tenant_id)
    and phone = v_phone;

  if v_row.id is null then
    return null;
  end if;

  return jsonb_build_object(
    'id', v_row.id,
    'name', v_row.name,
    'phone', v_row.phone,
    'secondary_phone', v_row.secondary_phone,
    'address', v_row.address,
    'district', v_row.district,
    'thana', v_row.thana,
    'addresses', v_row.addresses,
    'tenant_id', v_row.tenant_id,
    'created_at', v_row.created_at,
    'updated_at', v_row.updated_at
  );
end;
$$;

commit;
