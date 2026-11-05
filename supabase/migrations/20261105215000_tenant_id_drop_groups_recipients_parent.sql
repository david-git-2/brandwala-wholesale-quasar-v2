-- Phase 4b: drop parent_tenant_id on customer_groups + recipient_profiles.

CREATE OR REPLACE FUNCTION "public"."assert_staff_can_place_dropship_order_on_behalf"("p_shop_id" bigint, "p_customer_group_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_shop public.shops%rowtype;
BEGIN
  SELECT * INTO v_shop
  FROM public.shops
  WHERE id = p_shop_id
    AND is_active = true
    AND deleted_at IS NULL;

  IF v_shop.id IS NULL THEN
    RAISE EXCEPTION 'shop not found or inactive';
  END IF;

  IF v_shop.shop_type <> 'dropship' THEN
    RAISE EXCEPTION 'shop is not dropship';
  END IF;

  IF NOT public.membership_has_module_action(v_shop.tenant_id, 'shop_order_mgmt', 'edit')
     AND NOT public.membership_has_module_action(
       public.resolve_parent_tenant_id(v_shop.tenant_id), 'shop_order_mgmt', 'edit'
     )
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.customer_groups cg
    WHERE cg.id = p_customer_group_id
      AND cg.is_active = true
      AND cg.deleted_at IS NULL
      AND cg.tenant_id = public.resolve_parent_tenant_id(v_shop.tenant_id)
  ) THEN
    RAISE EXCEPTION 'customer group not found';
  END IF;
END;
$$;


ALTER FUNCTION "public"."assert_staff_can_place_dropship_order_on_behalf"("p_shop_id" bigint, "p_customer_group_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."assign_customer_group_member_role"("p_cgm_id" bigint, "p_tenant_role_id" bigint) RETURNS "public"."customer_group_members"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_member public.customer_group_members;
  v_group public.customer_groups;
  v_role public.tenant_roles;
  v_books_id bigint;
begin
  select * into v_member from public.customer_group_members where id = p_cgm_id;
  if v_member.id is null then
    raise exception 'Customer group member not found';
  end if;

  select * into v_group from public.customer_groups where id = v_member.customer_group_id;
  if v_group.id is null then
    raise exception 'Customer group not found';
  end if;

  v_books_id := public.resolve_parent_tenant_id(v_group.tenant_id);

  if not public.user_is_tenant_admin(v_books_id) then
    raise exception 'Unauthorized';
  end if;

  select * into v_role from public.tenant_roles where id = p_tenant_role_id;
  if v_role.id is null then
    raise exception 'Role not found';
  end if;

  if public.resolve_parent_tenant_id(v_role.tenant_id) is distinct from v_books_id then
    raise exception 'Role and Customer group member must belong to the same tenant';
  end if;

  if v_role.scope <> 'shop' then
    raise exception 'Role scope must be shop for customer group members';
  end if;

  update public.customer_group_members
  set
    tenant_role_id = p_tenant_role_id,
    updated_at = now()
  where id = p_cgm_id
  returning * into v_member;

  return v_member;
end;
$$;


ALTER FUNCTION "public"."assign_customer_group_member_role"("p_cgm_id" bigint, "p_tenant_role_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_act_on_parent_tenant_stock"("p_parent_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
        and cg.tenant_id = p_parent_tenant_id
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


ALTER FUNCTION "public"."can_act_on_parent_tenant_stock"("p_parent_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_manage_customer_group_member"("p_customer_group_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.customer_groups cg
    where cg.id = p_customer_group_id
      and public.can_manage_customer_group(cg.tenant_id)
  );
$$;


ALTER FUNCTION "public"."can_manage_customer_group_member"("p_customer_group_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_shop_login_access"("p_email" "text", "p_tenant_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("has_match" boolean, "matched_role" "public"."customer_group_role", "member_id" bigint, "member_name" "text", "member_email" "text", "member_tenant_id" bigint, "customer_group_id" bigint, "customer_group_name" "text", "member_is_active" boolean, "customer_group_is_active" boolean, "member_created_at" timestamp with time zone, "member_updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
          and cg.tenant_id
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


ALTER FUNCTION "public"."check_shop_login_access"("p_email" "text", "p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_customer_account"("p_tenant_id" bigint, "p_group_name" "text", "p_admin_name" "text" DEFAULT NULL::"text", "p_admin_email" "text" DEFAULT NULL::"text", "p_phone" "text" DEFAULT NULL::"text", "p_address" "text" DEFAULT NULL::"text", "p_accent_color" "text" DEFAULT '#B45F34'::"text", "p_phone_country_code" "text" DEFAULT '+880'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_group public.customer_groups;
  v_profile public.profiles;
  v_profile_id bigint;
  v_books_id bigint;
  v_clean_phone text;
  v_clean_code text;
  v_clean_group_name text;
  v_clean_color text;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not public.can_administer_customer_group(v_books_id) then
    raise exception 'Only parent tenant admins can create customer groups';
  end if;

  v_clean_group_name := trim(coalesce(p_group_name, ''));
  v_clean_phone := nullif(regexp_replace(trim(coalesce(p_phone, '')), '[^0-9]', '', 'g'), '');
  v_clean_code := coalesce(nullif(trim(coalesce(p_phone_country_code, '')), ''), '+880');
  if v_clean_code not like '+%' then
    v_clean_code := '+' || v_clean_code;
  end if;
  v_clean_color := coalesce(nullif(trim(coalesce(p_accent_color, '')), ''), '#B45F34');

  if v_clean_group_name = '' then
    raise exception 'Group / Company name is required';
  end if;
  if v_clean_phone is null then
    raise exception 'Phone is required';
  end if;

  if exists (
    select 1
    from public.profiles pr
    left join public.customer_groups cg on cg.id = pr.customer_group_id
    where pr.profile_type = 'customer'::public.profile_party_type
      and pr.parent_tenant_id = v_books_id
      and pr.phone_country_code = v_clean_code
      and pr.phone = v_clean_phone
      and pr.is_phone_unique
      and (cg.id is null or cg.deleted_at is null)
  ) then
    raise exception 'This phone is already used by another customer';
  end if;

  insert into public.customer_groups (
    tenant_id,
    name,
    accent_color,
    is_active
  ) values (
    v_books_id,
    v_clean_group_name,
    v_clean_color,
    true
  )
  returning * into v_group;

  select * into v_profile
  from public.profiles
  where customer_group_id = v_group.id
    and profile_type = 'customer'::public.profile_party_type
  order by id asc
  limit 1;

  if v_profile.id is null then
    insert into public.profiles (
      parent_tenant_id,
      profile_type,
      subject_id,
      customer_group_id,
      operating_tenant_id,
      name,
      phone,
      phone_country_code,
      address,
      accent_color,
      is_active,
      created_at,
      updated_at
    ) values (
      v_books_id,
      'customer'::public.profile_party_type,
      v_group.id,
      v_group.id,
      v_books_id,
      v_clean_group_name,
      v_clean_phone,
      v_clean_code,
      nullif(trim(coalesce(p_address, '')), ''),
      v_clean_color,
      true,
      now(),
      now()
    )
    returning * into v_profile;

    update public.profiles
    set subject_id = v_profile.id
    where id = v_profile.id;
  else
    update public.profiles
    set
      name = v_clean_group_name,
      phone = v_clean_phone,
      phone_country_code = v_clean_code,
      parent_tenant_id = v_books_id,
      operating_tenant_id = v_books_id,
      address = coalesce(nullif(trim(coalesce(p_address, '')), ''), address),
      updated_at = now()
    where id = v_profile.id
    returning * into v_profile;
  end if;

  insert into public.cashbook_accounts (
    tenant_id,
    parent_tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    locked_balance,
    pending_balance
  ) values (
    v_books_id,
    v_books_id,
    'customer',
    v_profile.id,
    'BDT',
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code) do nothing;

  return jsonb_build_object(
    'id', v_group.id,
    'customer_group_id', v_group.id,
    'profile_id', v_profile.id,
    'group_name', v_group.name,
    'admin_name', v_profile.name,
    'email', v_profile.email,
    'phone', concat_ws(' ', v_profile.phone_country_code, v_profile.phone),
    'address', v_profile.address,
    'accent_color', coalesce(v_group.accent_color, '#B45F34'),
    'is_active', v_group.is_active,
    'member_count', 0,
    'wallet_available_balance', 0,
    'created_at', v_group.created_at
  );
end;
$$;


ALTER FUNCTION "public"."create_customer_account"("p_tenant_id" bigint, "p_group_name" "text", "p_admin_name" "text", "p_admin_email" "text", "p_phone" "text", "p_address" "text", "p_accent_color" "text", "p_phone_country_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_customer_group_id"("p_tenant_id" bigint) RETURNS bigint
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with candidates as (
    select distinct cg.id
    from public.customer_groups cg
    join public.customer_group_members cgm on cgm.customer_group_id = cg.id
    where p_tenant_id is not null
      and cg.is_active = true
      and cg.deleted_at is null
      and cgm.is_active = true
      and lower(trim(cgm.email)) = public.current_user_email()
      and cg.tenant_id = public.resolve_parent_tenant_id(p_tenant_id)
      and (
        p_tenant_id = cg.tenant_id
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


ALTER FUNCTION "public"."current_customer_group_id"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_customer_group"("p_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
  v_deleted_at timestamptz;
begin
  select cg.tenant_id, cg.deleted_at
  into v_books_id, v_deleted_at
  from public.customer_groups cg
  where cg.id = p_id;

  if v_books_id is null then
    raise exception 'Customer group not found';
  end if;

  if not public.can_administer_customer_group(v_books_id) then
    raise exception 'Only parent tenant admins can delete customer groups';
  end if;

  if v_deleted_at is not null then
    return;
  end if;

  update public.customer_groups
  set
    deleted_at = now(),
    is_active = false,
    updated_at = now()
  where id = p_id
    and deleted_at is null;
end;
$$;


ALTER FUNCTION "public"."delete_customer_group"("p_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_customer_create_conflict"("p_tenant_id" bigint, "p_phone" "text" DEFAULT NULL::"text", "p_phone_country_code" "text" DEFAULT NULL::"text", "p_group_name" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
  v_phone text;
  v_code text;
  v_name text;
  v_phone_group text;
  v_name_group text;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_phone := public.normalize_customer_national_phone(p_phone);
  v_code := nullif(trim(coalesce(p_phone_country_code, '')), '');
  if v_code is not null and v_code not like '+%' then
    v_code := '+' || v_code;
  end if;
  v_name := nullif(trim(coalesce(p_group_name, '')), '');

  if v_phone is not null and v_code is not null then
    select cg.name
    into v_phone_group
    from public.profiles pr
    left join public.customer_groups cg on cg.id = pr.customer_group_id
    where pr.profile_type = 'customer'::public.profile_party_type
      and pr.parent_tenant_id = v_books_id
      and pr.phone_country_code = v_code
      and pr.phone = v_phone
      and pr.is_phone_unique
      and (cg.id is null or cg.deleted_at is null)
    order by pr.id
    limit 1;
  end if;

  if v_name is not null then
    select cg.name
    into v_name_group
    from public.customer_groups cg
    where cg.tenant_id = v_books_id
      and cg.deleted_at is null
      and lower(cg.name) = lower(v_name)
    order by cg.id
    limit 1;
  end if;

  return jsonb_build_object(
    'phone_group_name', v_phone_group,
    'name_group_name', v_name_group
  );
end;
$$;


ALTER FUNCTION "public"."find_customer_create_conflict"("p_tenant_id" bigint, "p_phone" "text", "p_phone_country_code" "text", "p_group_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_recipient_profile_by_phone"("p_tenant_id" bigint, "p_phone" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_phone text;
  v_row public.recipient_profiles%rowtype;
  v_can_access boolean;
  v_parent_id bigint;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  v_can_access := public.is_tenant_staff(p_tenant_id)
    or public.current_customer_group_id(p_tenant_id) is not null
    or public.user_can_manage_parent_tenant(p_tenant_id)
    or public.has_active_tenant_membership(p_tenant_id);

  if not v_can_access then
    raise exception 'access denied';
  end if;

  begin
    v_phone := public.normalize_bd_mobile(p_phone);
  exception when others then
    return null;
  end;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select * into v_row
  from public.recipient_profiles
  where (tenant_id = v_parent_id or tenant_id = p_tenant_id)
    and phone = v_phone
  order by (tenant_id = v_parent_id) desc, updated_at desc
  limit 1;

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


ALTER FUNCTION "public"."get_recipient_profile_by_phone"("p_tenant_id" bigint, "p_phone" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_shop_bootstrap_context"("p_email" "text" DEFAULT NULL::"text", "p_tenant_id" bigint DEFAULT NULL::bigint, "p_customer_group_member_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("member_id" bigint, "member_name" "text", "member_email" "text", "member_role" "public"."customer_group_role", "member_is_active" boolean, "customer_group_id" bigint, "customer_group_name" "text", "customer_group_is_active" boolean, "customer_group_accent_color" "text", "tenant_id" bigint, "tenant_name" "text", "tenant_slug" "text", "tenant_is_active" boolean, "active_module_keys" "text"[], "tenant_role_id" bigint, "is_admin" boolean, "effective_grants" "jsonb", "permission_version" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
    and cg.tenant_id = public.resolve_parent_tenant_id(p_tenant_id)
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


ALTER FUNCTION "public"."get_shop_bootstrap_context"("p_email" "text", "p_tenant_id" bigint, "p_customer_group_member_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_shop_customer_access_page"("p_shop_id" bigint, "p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_shop_tenant_id bigint;
  v_books_id bigint;
  v_groups jsonb := '[]'::jsonb;
  v_access jsonb := '[]'::jsonb;
BEGIN
  IF p_shop_id IS NULL OR p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'shop_id and tenant_id are required';
  END IF;

  SELECT s.tenant_id
  INTO v_shop_tenant_id
  FROM public.shops s
  WHERE s.id = p_shop_id
    AND s.deleted_at IS NULL
    AND s.tenant_id = p_tenant_id;

  IF v_shop_tenant_id IS NULL THEN
    RAISE EXCEPTION 'shop not found';
  END IF;

  IF NOT public.user_can_access_tenant_fetch(v_shop_tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_books_id := public.resolve_parent_tenant_id(v_shop_tenant_id);

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', cg.id,
        'name', cg.name,
        'is_active', cg.is_active,
        'accent_color', cg.accent_color
      )
      ORDER BY cg.name
    ),
    '[]'::jsonb
  )
  INTO v_groups
  FROM public.customer_groups cg
  WHERE cg.tenant_id = v_books_id
    AND cg.deleted_at IS NULL;

  SELECT coalesce(jsonb_agg(to_jsonb(a)), '[]'::jsonb)
  INTO v_access
  FROM public.shop_customer_group_access a
  WHERE a.shop_id = p_shop_id;

  RETURN jsonb_build_object(
    'customer_groups', v_groups,
    'access_overrides', v_access
  );
END;
$$;


ALTER FUNCTION "public"."get_shop_customer_access_page"("p_shop_id" bigint, "p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_shop_permissions_for_customer"("p_shop_id" bigint) RETURNS TABLE("can_browse" boolean, "can_see_buy_price" boolean, "can_see_sell_price" boolean, "can_see_resell_minimum_price" boolean, "can_add_to_cart" boolean, "can_place_order" boolean, "can_negotiate" boolean, "can_view_quantity" boolean, "can_set_dropship_price" boolean)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
    and cg.tenant_id = public.resolve_parent_tenant_id(v_tenant_id);
end;
$$;


ALTER FUNCTION "public"."get_shop_permissions_for_customer"("p_shop_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_shop_permissions_for_customer_group"("p_shop_id" bigint, "p_customer_group_id" bigint) RETURNS TABLE("can_browse" boolean, "can_see_buy_price" boolean, "can_see_sell_price" boolean, "can_see_resell_minimum_price" boolean, "can_add_to_cart" boolean, "can_place_order" boolean, "can_negotiate" boolean, "can_view_quantity" boolean, "can_set_dropship_price" boolean)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_shop_active boolean;
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_shop_allows_negotiate boolean;
BEGIN
  SELECT is_active, tenant_id, shop_type
  INTO v_shop_active, v_tenant_id, v_shop_type
  FROM public.shops
  WHERE id = p_shop_id;

  IF v_shop_active IS NOT true THEN
    RETURN QUERY SELECT false, false, false, false, false, false, false, false, false;
    RETURN;
  END IF;

  v_shop_allows_negotiate := v_shop_type = 'vendor_catalog';

  RETURN QUERY
  SELECT
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE coalesce(access.can_browse, profile.default_can_browse, true)
      END,
      true
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE public.resolve_shop_can_see_buy_price(
          v_shop_type,
          access.can_see_buy_price,
          access.can_see_sell_price,
          profile.default_can_see_buy_price,
          profile.default_can_see_sell_price
        )
      END,
      true
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE CASE
          WHEN v_shop_type = 'dropship' THEN true
          ELSE coalesce(access.can_see_sell_price, profile.default_can_see_sell_price, true)
        END
      END,
      true
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE coalesce(access.can_see_resell_minimum_price, profile.default_can_see_resell_minimum_price, true)
      END,
      true
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE coalesce(access.can_add_to_cart, profile.default_can_add_to_cart, true)
      END,
      true
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE coalesce(access.can_place_order, profile.default_can_place_order, true)
      END,
      true
    ),
    coalesce(
      (
        CASE
          WHEN access.id IS NOT NULL AND access.status = false THEN false
          WHEN coalesce(profile.is_active, true) = false THEN false
          ELSE coalesce(access.can_negotiate, profile.default_can_negotiate, false)
        END
      ) AND v_shop_allows_negotiate,
      false
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE coalesce(access.can_view_quantity, profile.default_can_view_quantity, true)
      END,
      true
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE CASE
          WHEN v_shop_type = 'dropship' THEN true
          ELSE coalesce(access.can_set_dropship_price, profile.default_can_set_dropship_price, true)
        END
      END,
      true
    )
  FROM public.customer_groups cg
  LEFT JOIN public.shop_customer_group_access access
    ON access.customer_group_id = cg.id
   AND access.shop_id = p_shop_id
  LEFT JOIN public.customer_group_shop_profiles profile
    ON profile.customer_group_id = cg.id
   AND profile.tenant_id = v_tenant_id
  WHERE cg.id = p_customer_group_id
    AND cg.is_active = true
    AND cg.deleted_at IS NULL
    AND cg.tenant_id = public.resolve_parent_tenant_id(v_tenant_id);
END;
$$;


ALTER FUNCTION "public"."get_shop_permissions_for_customer_group"("p_shop_id" bigint, "p_customer_group_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_cart_owner"("p_customer_group_id" bigint, "p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
  select exists (
    select 1
    from public.customer_groups cg
    join public.customer_group_members cgm on cgm.customer_group_id = cg.id
    where p_customer_group_id is not null
      and p_tenant_id is not null
      and cg.id = p_customer_group_id
      and cg.is_active = true
      and cg.deleted_at is null
      and cgm.is_active = true
      and lower(trim(cgm.email)) = public.current_user_email()
      and cg.tenant_id = public.resolve_parent_tenant_id(p_tenant_id)
      and (
        p_tenant_id = cg.tenant_id
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
$$;


ALTER FUNCTION "public"."is_cart_owner"("p_customer_group_id" bigint, "p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_customer_accounts"("p_tenant_id" bigint, "p_search" "text" DEFAULT NULL::"text") RETURNS TABLE("id" bigint, "customer_group_id" bigint, "profile_id" bigint, "group_name" "text", "admin_name" "text", "email" "text", "phone" "text", "address" "text", "accent_color" "text", "is_active" boolean, "member_count" bigint, "wallet_available_balance" numeric, "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  return query
  select
    cg.id,
    cg.id as customer_group_id,
    bp.id as profile_id,
    cg.name as group_name,
    coalesce(bp.name, cg.name) as admin_name,
    bp.email,
    nullif(concat_ws(' ', bp.phone_country_code, bp.phone), '') as phone,
    bp.address,
    coalesce(cg.accent_color, '#B45F34') as accent_color,
    cg.is_active,
    coalesce(mem.cnt, 0::bigint) as member_count,
    coalesce(wa.available_balance, 0.00) as wallet_available_balance,
    cg.created_at
  from public.customer_groups cg
  left join public.profiles bp
    on bp.customer_group_id = cg.id
   and bp.parent_tenant_id = v_books_id
  left join (
    select cgm.customer_group_id as c_group_id, count(*) as cnt
    from public.customer_group_members cgm
    group by cgm.customer_group_id
  ) mem on mem.c_group_id = cg.id
  left join public.cashbook_accounts wa
    on wa.parent_tenant_id = v_books_id
   and wa.entity_type = 'customer'
   and wa.entity_id = bp.id
   and wa.currency_code = 'BDT'
  where cg.tenant_id = v_books_id
    and cg.deleted_at is null
    and (
      p_search is null
      or trim(p_search) = ''
      or cg.name ilike '%' || trim(p_search) || '%'
      or bp.name ilike '%' || trim(p_search) || '%'
      or bp.email ilike '%' || trim(p_search) || '%'
      or bp.phone ilike '%' || trim(p_search) || '%'
      or bp.phone_country_code ilike '%' || trim(p_search) || '%'
      or bp.address ilike '%' || trim(p_search) || '%'
    )
  order by cg.id desc;
end;
$$;


ALTER FUNCTION "public"."list_customer_accounts"("p_tenant_id" bigint, "p_search" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_customer_accounts_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
  v_page integer;
  v_page_size integer;
  v_total_count bigint;
  v_total_pages integer;
  v_data jsonb;
  v_search text;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_page := greatest(coalesce(p_page, 1), 1);
  v_page_size := greatest(1, least(coalesce(p_page_size, 20), 200));
  v_search := nullif(trim(coalesce(p_search, '')), '');

  select count(*)
  into v_total_count
  from public.customer_groups cg
  left join public.profiles bp
    on bp.customer_group_id = cg.id
   and bp.parent_tenant_id = v_books_id
  where cg.tenant_id = v_books_id
    and cg.deleted_at is null
    and (
      v_search is null
      or cg.name ilike '%' || v_search || '%'
      or bp.name ilike '%' || v_search || '%'
      or bp.email ilike '%' || v_search || '%'
      or bp.phone ilike '%' || v_search || '%'
      or bp.phone_country_code ilike '%' || v_search || '%'
      or bp.address ilike '%' || v_search || '%'
    );

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      cg.id as sort_id,
      jsonb_build_object(
        'id', cg.id,
        'customer_group_id', cg.id,
        'profile_id', bp.id,
        'group_name', cg.name,
        'admin_name', coalesce(bp.name, cg.name),
        'email', bp.email,
        'phone', nullif(concat_ws(' ', bp.phone_country_code, bp.phone), ''),
        'address', bp.address,
        'accent_color', coalesce(cg.accent_color, '#B45F34'),
        'is_active', cg.is_active,
        'member_count', coalesce(mem.cnt, 0::bigint),
        'wallet_available_balance', coalesce(wa.available_balance, 0.00),
        'created_at', cg.created_at
      ) as row_json
    from public.customer_groups cg
    left join public.profiles bp
      on bp.customer_group_id = cg.id
     and bp.parent_tenant_id = v_books_id
    left join (
      select cgm.customer_group_id as c_group_id, count(*) as cnt
      from public.customer_group_members cgm
      group by cgm.customer_group_id
    ) mem on mem.c_group_id = cg.id
    left join public.cashbook_accounts wa
      on wa.parent_tenant_id = v_books_id
     and wa.entity_type = 'customer'
     and wa.entity_id = bp.id
     and wa.currency_code = 'BDT'
    where cg.tenant_id = v_books_id
      and cg.deleted_at is null
      and (
        v_search is null
        or cg.name ilike '%' || v_search || '%'
        or bp.name ilike '%' || v_search || '%'
        or bp.email ilike '%' || v_search || '%'
        or bp.phone ilike '%' || v_search || '%'
        or bp.phone_country_code ilike '%' || v_search || '%'
        or bp.address ilike '%' || v_search || '%'
      )
    order by cg.id desc
    limit v_page_size
    offset (v_page - 1) * v_page_size
  ) q;

  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::numeric / v_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', v_page,
      'page_size', v_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$$;


ALTER FUNCTION "public"."list_customer_accounts_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_customer_groups_payment_summary"("p_tenant_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0, "p_only_with_due" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_result jsonb;
begin
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_result
  from (
    select
      cg.id,
      cg.name,
      'CUST-GRP-' || lpad(cg.id::text, 4, '0') as account_code,
      coalesce(
        (select bp.phone from public.billing_profiles bp where bp.customer_group_id = cg.id and bp.phone is not null limit 1),
        '—'
      ) as phone,
      coalesce(
        (select array_agg(bp.name order by bp.name) from public.billing_profiles bp where bp.customer_group_id = cg.id),
        array[]::text[]
      ) as branches,
      coalesce(
        count(distinct si.id) filter (where si.invoice_status = 'issued' and si.due_amount > 0),
        0
      )::int as open_invoice_count,
      coalesce(
        sum(si.total_amount) filter (where si.invoice_status = 'issued'),
        0.00
      )::numeric(12,2) as total_invoiced,
      coalesce(
        sum(si.paid_amount) filter (where si.invoice_status = 'issued'),
        0.00
      )::numeric(12,2) as total_paid,
      coalesce(
        sum(si.written_off_amount) filter (where si.invoice_status = 'issued'),
        0.00
      )::numeric(12,2) as total_written_off,
      coalesce(
        sum(si.due_amount) filter (where si.invoice_status = 'issued'),
        0.00
      )::numeric(12,2) as total_due,
      (
        select max(gp.payment_date)
        from public.pays gp
        where gp.customer_group_id = cg.id
           or gp.profile_id in (select id from public.billing_profiles where customer_group_id = cg.id)
      ) as last_payment_date
    from public.customer_groups cg
    left join public.billing_profiles bp on bp.customer_group_id = cg.id
    left join public.bills si on si.profile_id = bp.id
    where (cg.tenant_id = v_parent_id or cg.tenant_id = p_tenant_id)
      and (
        p_search is null
        or trim(p_search) = ''
        or cg.name ilike '%' || trim(p_search) || '%'
        or bp.name ilike '%' || trim(p_search) || '%'
        or bp.phone ilike '%' || trim(p_search) || '%'
      )
    group by cg.id, cg.name
    having (
      not coalesce(p_only_with_due, false)
      or coalesce(
        sum(si.due_amount) filter (where si.invoice_status = 'issued'),
        0.00
      ) > 0.00
    )
    order by total_due desc, cg.name asc
    limit coalesce(p_limit, 50)
    offset coalesce(p_offset, 0)
  ) r;

  return v_result;
end;
$$;


ALTER FUNCTION "public"."list_customer_groups_payment_summary"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer, "p_only_with_due" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_customer_groups_payout_summary"("p_tenant_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_customer_group_id" bigint DEFAULT NULL::bigint, "p_only_with_payable" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_result jsonb;
  v_search text;
begin
  if p_tenant_id is null then
    return '[]'::jsonb;
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_search := nullif(trim(p_search), '');

  if not (
    public.is_superadmin()
    or public.is_tenant_staff(p_tenant_id)
    or public.membership_has_module_action(v_parent_id, 'payments', 'view')
    or public.membership_has_module_action(p_tenant_id, 'payments', 'view')
  ) then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_result
  from (
    select
      cg.id as customer_group_id,
      cg.name,
      ('CUST-GRP-' || lpad(cg.id::text, 4, '0')) as account_code,
      coalesce(sum(wa.available_balance), 0.00)::numeric(12, 2) as payable_balance,
      (
        select coalesce(
          jsonb_agg(
            jsonb_build_object(
              'profile_id', pr2.id,
              'name', pr2.name,
              'payable_balance', coalesce(wa2.available_balance, 0.00)
            )
            order by coalesce(wa2.available_balance, 0.00) desc, pr2.name
          ),
          '[]'::jsonb
        )
        from public.profiles pr2
        left join public.cashbook_accounts wa2
          on wa2.parent_tenant_id = v_parent_id
         and wa2.entity_type = 'customer'
         and wa2.entity_id = pr2.id
         and wa2.currency_code = 'BDT'
        where pr2.customer_group_id = cg.id
          and pr2.profile_type = 'customer'::public.profile_party_type
          and (pr2.operating_tenant_id = v_parent_id or pr2.operating_tenant_id = p_tenant_id)
      ) as profiles
    from public.customer_groups cg
    inner join public.profiles pr
      on pr.customer_group_id = cg.id
     and (pr.operating_tenant_id = v_parent_id or pr.operating_tenant_id = p_tenant_id)
    left join public.cashbook_accounts wa
      on wa.parent_tenant_id = v_parent_id
     and wa.entity_type = 'customer'
     and wa.entity_id = pr.id
     and wa.currency_code = 'BDT'
    where (cg.tenant_id = v_parent_id or cg.tenant_id = p_tenant_id)
      and (p_customer_group_id is null or cg.id = p_customer_group_id)
      and (
        v_search is null
        or cg.name ilike '%' || v_search || '%'
        or pr.name ilike '%' || v_search || '%'
        or coalesce(pr.phone, '') ilike '%' || v_search || '%'
        or coalesce(pr.email, '') ilike '%' || v_search || '%'
      )
    group by cg.id, cg.name
    having (
      not coalesce(p_only_with_payable, false)
      or coalesce(sum(wa.available_balance), 0.00) > 0.00
    )
    order by payable_balance desc nulls last, cg.name asc
    limit greatest(least(coalesce(p_limit, 50), 200), 1)
  ) r;

  return v_result;
end;
$$;


ALTER FUNCTION "public"."list_customer_groups_payout_summary"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_customer_group_id" bigint, "p_only_with_payable" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recipient_profile_valid_for_issuer"("p_recipient_profile_id" bigint, "p_issued_by_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.recipient_profiles rp
    where rp.id = p_recipient_profile_id
      and (
        rp.tenant_id = p_issued_by_tenant_id
        or rp.tenant_id = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
        or rp.tenant_id
          = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
        or exists (
          select 1
          from public.tenants t
          where t.id = rp.tenant_id
            and t.parent_id = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
        )
      )
  );
$$;


ALTER FUNCTION "public"."recipient_profile_valid_for_issuer"("p_recipient_profile_id" bigint, "p_issued_by_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_fn_cgm_permission_guardrails"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_role_scope text;
  v_role_books bigint;
  v_cg_books bigint;
begin
  if new.tenant_role_id is not null then
    select tr.scope, public.resolve_parent_tenant_id(tr.tenant_id)
    into v_role_scope, v_role_books
    from public.tenant_roles tr
    where tr.id = new.tenant_role_id;

    select public.resolve_parent_tenant_id(cg.tenant_id)
    into v_cg_books
    from public.customer_groups cg
    where cg.id = new.customer_group_id;

    if v_role_books is distinct from v_cg_books then
      raise exception 'Cross-tenant role assignment is not allowed';
    end if;

    if v_role_scope is distinct from 'shop' then
      raise exception 'Scope mismatch: customer group member cannot be assigned a % scoped role', v_role_scope;
    end if;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."trg_fn_cgm_permission_guardrails"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_fn_sync_cgm_tenant_role"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_target_slug text;
  v_role_id bigint;
  v_role_books bigint;
  v_cg_books bigint;
begin
  if new.tenant_role_id is not null then
    select public.resolve_parent_tenant_id(tr.tenant_id)
    into v_role_books
    from public.tenant_roles tr
    where tr.id = new.tenant_role_id;

    select public.resolve_parent_tenant_id(cg.tenant_id)
    into v_cg_books
    from public.customer_groups cg
    where cg.id = new.customer_group_id;

    if v_role_books is not distinct from v_cg_books
       and not (tg_op = 'UPDATE' and old.role is distinct from new.role) then
      return new;
    end if;
  end if;

  if new.tenant_role_id is null or (tg_op = 'UPDATE' and old.role is distinct from new.role) then
    select cg.tenant_id
    into v_tenant_id
    from public.customer_groups cg
    where cg.id = new.customer_group_id;

    if v_tenant_id is not null then
      v_target_slug := case new.role
        when 'admin' then 'customer-admin'
        when 'manager' then 'manager'
        when 'staff' then 'customer-staff'
        else 'customer-staff'
      end;

      select tr.id into v_role_id
      from public.tenant_roles tr
      where tr.tenant_id = v_tenant_id
        and tr.scope = 'shop'
        and (tr.slug = v_target_slug or (new.role = 'admin' and tr.is_admin = true))
      order by tr.is_admin desc, tr.id asc
      limit 1;

      if v_role_id is not null then
        new.tenant_role_id := v_role_id;
      end if;
    end if;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."trg_fn_sync_cgm_tenant_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_recipient_profile_by_phone"("p_tenant_id" bigint, "p_name" "text", "p_phone" "text", "p_secondary_phone" "text" DEFAULT NULL::"text", "p_address" "text" DEFAULT NULL::"text", "p_district" "text" DEFAULT NULL::"text", "p_thana" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_phone text;
  v_secondary text;
  v_name text;
  v_address text;
  v_district text;
  v_thana text;
  v_entry jsonb;
  v_addresses jsonb;
  v_next jsonb := '[]'::jsonb;
  v_elem jsonb;
  v_matched boolean := false;
  v_row public.recipient_profiles%rowtype;
  v_parent_id bigint;
  v_insert_tenant_id bigint;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not (
    public.has_active_tenant_membership(p_tenant_id)
    or public.user_can_manage_parent_tenant(p_tenant_id)
    or public.current_customer_group_id(p_tenant_id) is not null
  ) then
    raise exception 'access denied';
  end if;

  v_phone := public.normalize_bd_mobile(p_phone);
  v_name := nullif(trim(coalesce(p_name, '')), '');
  if v_name is null then
    raise exception 'Recipient name is required';
  end if;
  v_address := nullif(trim(coalesce(p_address, '')), '');
  if v_address is null then
    raise exception 'Recipient address is required';
  end if;
  v_district := nullif(trim(coalesce(p_district, '')), '');
  v_thana := nullif(trim(coalesce(p_thana, '')), '');

  if nullif(trim(coalesce(p_secondary_phone, '')), '') is not null then
    begin
      v_secondary := public.normalize_bd_mobile(p_secondary_phone);
    exception when others then
      v_secondary := nullif(trim(p_secondary_phone), '');
    end;
  else
    v_secondary := null;
  end if;

  v_entry := jsonb_build_object(
    'id', gen_random_uuid()::text,
    'line', v_address,
    'district', v_district,
    'thana', v_thana,
    'is_default', true,
    'updated_at', now()
  );

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  v_insert_tenant_id := v_parent_id;

  select * into v_row
  from public.recipient_profiles
  where (tenant_id = v_parent_id or tenant_id = p_tenant_id)
    and phone = v_phone
  order by (tenant_id = v_parent_id) desc, updated_at desc
  limit 1
  for update;

  if v_row.id is null then
    insert into public.recipient_profiles (
      tenant_id, name, phone, secondary_phone, address, district, thana, addresses
    )
    values (
      v_insert_tenant_id, v_name, v_phone, v_secondary, v_address, v_district, v_thana,
      jsonb_build_array(v_entry)
    )
    returning * into v_row;
  else
    v_addresses := coalesce(v_row.addresses, '[]'::jsonb);
    v_next := '[]'::jsonb;
    v_matched := false;

    for v_elem in select * from jsonb_array_elements(v_addresses)
    loop
      if v_elem->>'line' = v_address then
        v_matched := true;
        v_next := v_next || jsonb_build_array(
          jsonb_build_object(
            'id', coalesce(v_elem->>'id', gen_random_uuid()::text),
            'line', v_address,
            'district', v_district,
            'thana', v_thana,
            'is_default', true,
            'updated_at', now()
          )
        );
      else
        v_next := v_next || jsonb_build_array(
          jsonb_set(v_elem, '{is_default}', 'false'::jsonb)
        );
      end if;
    end loop;

    if not v_matched then
      v_next := v_next || jsonb_build_array(v_entry);
    end if;

    update public.recipient_profiles
    set
      name = v_name,
      secondary_phone = coalesce(v_secondary, secondary_phone),
      address = v_address,
      district = v_district,
      thana = v_thana,
      addresses = v_next,
      updated_at = now()
    where id = v_row.id
    returning * into v_row;
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


ALTER FUNCTION "public"."upsert_recipient_profile_by_phone"("p_tenant_id" bigint, "p_name" "text", "p_phone" "text", "p_secondary_phone" "text", "p_address" "text", "p_district" "text", "p_thana" "text") OWNER TO "postgres";


DROP TRIGGER IF EXISTS trg_customer_groups_sync_parent_tenant ON public.customer_groups;
DROP FUNCTION IF EXISTS public.trg_customer_groups_sync_parent_tenant();
DROP TRIGGER IF EXISTS trg_recipient_profiles_set_parent_tenant_id ON public.recipient_profiles;

DROP INDEX IF EXISTS public.customer_groups_parent_tenant_id_idx;
DROP INDEX IF EXISTS public.customer_groups_parent_live_idx;
DROP INDEX IF EXISTS public.recipient_profiles_parent_tenant_id_idx;

ALTER TABLE public.customer_groups DROP CONSTRAINT IF EXISTS customer_groups_parent_tenant_id_fkey;
ALTER TABLE public.recipient_profiles DROP CONSTRAINT IF EXISTS recipient_profiles_parent_tenant_id_fkey;

DROP POLICY IF EXISTS customer_groups_select ON public.customer_groups;
CREATE POLICY "customer_groups_select" ON "public"."customer_groups" FOR SELECT TO "authenticated" USING (("public"."can_manage_customer_group"("tenant_id") OR "public"."is_tenant_staff"("tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."tenants" "child"
  WHERE (("child"."parent_id" = "customer_groups"."tenant_id") AND "public"."is_tenant_staff"("child"."id"))))));

DROP POLICY IF EXISTS recipient_profiles_select ON public.recipient_profiles;
DROP POLICY IF EXISTS recipient_profiles_write ON public.recipient_profiles;
CREATE POLICY "recipient_profiles_select" ON "public"."recipient_profiles" FOR SELECT TO "authenticated" USING (("public"."has_active_tenant_membership"("tenant_id") OR "public"."user_can_manage_parent_tenant"("tenant_id")));
CREATE POLICY "recipient_profiles_write" ON "public"."recipient_profiles" TO "authenticated" USING (("public"."membership_has_module_action"("tenant_id", 'recipient_profile'::"text", 'edit'::"text") OR "public"."membership_has_module_action"("tenant_id", 'customer'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("tenant_id"))) WITH CHECK (("public"."membership_has_module_action"("tenant_id", 'recipient_profile'::"text", 'edit'::"text") OR "public"."membership_has_module_action"("tenant_id", 'customer'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("tenant_id")));

ALTER TABLE public.customer_groups DROP COLUMN IF EXISTS parent_tenant_id;
ALTER TABLE public.recipient_profiles DROP COLUMN IF EXISTS parent_tenant_id;

CREATE INDEX IF NOT EXISTS customer_groups_parent_live_idx ON public.customer_groups USING btree (tenant_id) WHERE (deleted_at IS NULL);
