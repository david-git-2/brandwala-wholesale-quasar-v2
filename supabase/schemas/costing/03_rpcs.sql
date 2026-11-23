-- Costing domain rpcs (extracted from public.sql)

CREATE OR REPLACE FUNCTION "public"."apply_costing_item_calculations"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_cargo_rate_1kg numeric(12,2);
  v_cargo_rate_2kg numeric(12,2);
  v_conversion_rate numeric(12,2);
  v_admin_profit_rate numeric(12,2);
  v_total_weight integer;
  v_auxiliary_price_gbp numeric(12,2);
  v_item_price_gbp numeric(12,2);
  v_cargo_rate numeric(12,2);
  v_costing_price_gbp numeric(12,2);
  v_costing_price_bdt integer;
  v_calculated_offer_price_bdt integer;
begin
  select
    cf.cargo_rate_1kg,
    cf.cargo_rate_2kg,
    cf.conversion_rate,
    cf.admin_profit_rate
  into
    v_cargo_rate_1kg,
    v_cargo_rate_2kg,
    v_conversion_rate,
    v_admin_profit_rate
  from public.costing_files cf
  where cf.id = new.costing_file_id;

  v_total_weight := coalesce(new.product_weight, 0) + coalesce(new.package_weight, 0);
  v_auxiliary_price_gbp := public.calculate_costing_auxiliary_price_gbp(
    new.price_in_web_gbp,
    new.delivery_price_gbp
  )::numeric(12,2);

  v_item_price_gbp := round(
    (
      coalesce(new.price_in_web_gbp, 0)
      + coalesce(new.delivery_price_gbp, 0)
      + coalesce(v_auxiliary_price_gbp, 0)
    )::numeric,
    2
  );

  if coalesce(new.cargo_rate_is_manual, false) and new.cargo_rate is not null then
    v_cargo_rate := round(new.cargo_rate::numeric, 2);
  elsif v_item_price_gbp > 10 then
    v_cargo_rate := coalesce(v_cargo_rate_2kg, 0);
  else
    v_cargo_rate := coalesce(v_cargo_rate_1kg, 0);
  end if;

  v_cargo_rate := round(v_cargo_rate::numeric, 2);

  v_costing_price_gbp := round(
    (
      coalesce(v_item_price_gbp, 0)
      + (coalesce(v_total_weight, 0) / 1000.0) * coalesce(v_cargo_rate, 0)
    )::numeric,
    2
  );

  v_costing_price_bdt := public.round_bdt_up_to_zero_or_five(
    coalesce(v_costing_price_gbp, 0) * coalesce(v_conversion_rate, 0)
  );

  v_calculated_offer_price_bdt := public.round_bdt_up_to_zero_or_five(
    v_costing_price_bdt + (v_costing_price_bdt * coalesce(v_admin_profit_rate, 0) / 100.0)
  );

  new.auxiliary_price_gbp := v_auxiliary_price_gbp;
  new.item_price_gbp := v_item_price_gbp;
  new.cargo_rate := v_cargo_rate;
  new.costing_price_gbp := v_costing_price_gbp;
  new.costing_price_bdt := v_costing_price_bdt;
  new.offer_price_bdt := coalesce(new.offer_price_override_bdt, v_calculated_offer_price_bdt);

  return new;
end;
$$;

ALTER FUNCTION "public"."apply_costing_item_calculations"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."calculate_costing_item_type_surcharge_gbp"("p_item_type" "text") RETURNS numeric
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
declare
  v_normalized_type text;
begin
  v_normalized_type := lower(trim(coalesce(p_item_type, '')));

  if v_normalized_type in ('watch', 'perfume') then
    return 3;
  end if;

  return 0;
end;
$$;

ALTER FUNCTION "public"."calculate_costing_item_type_surcharge_gbp"("p_item_type" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."can_admin_manage_costing_file"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    public.is_superadmin()
    or public.is_tenant_admin(p_tenant_id)
$$;

ALTER FUNCTION "public"."can_admin_manage_costing_file"("p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."can_customer_access_costing_file"("p_customer_group_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select public.is_customer_group_member(p_customer_group_id)
$$;

ALTER FUNCTION "public"."can_customer_access_costing_file"("p_customer_group_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."can_manage_costing_file_viewers"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select public.can_admin_manage_costing_file(p_tenant_id);
$$;

ALTER FUNCTION "public"."can_manage_costing_file_viewers"("p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."can_manage_costing_item"("p_file_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.product_based_costing_files f
    where f.id = p_file_id
      and public.can_manage_costing(f.tenant_id)
  )
$$;

ALTER FUNCTION "public"."can_manage_costing_item"("p_file_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."can_staff_access_costing_file"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select public.is_tenant_staff(p_tenant_id)
$$;

ALTER FUNCTION "public"."can_staff_access_costing_file"("p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."can_tenant_view_costing_file_viewer"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_authenticated_email()
      and m.tenant_id = p_tenant_id
      and m.role = 'viewer'
      and m.is_active = true
  );
$$;

ALTER FUNCTION "public"."can_tenant_view_costing_file_viewer"("p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."can_view_costing_file"("p_costing_file_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.costing_files cf
    where cf.id = p_costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
        or (
          public.is_assigned_costing_file_viewer(cf.id)
          and cf.status::text in ('po_placed', 'completed')
        )
        or (
          public.can_customer_access_costing_file(cf.customer_group_id)
          and (
            lower(trim(cf.created_by_email)) = public.current_user_email()
            or cf.status = 'draft'
            or public.is_customer_group_admin_or_negotiator(cf.customer_group_id)
            or (
              cf.status = 'offered'
              and public.is_internal_costing_file_creator(cf.tenant_id, cf.created_by_email)
            )
          )
        )
      )
  );
$$;

ALTER FUNCTION "public"."can_view_costing_file"("p_costing_file_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."can_view_costing_file_items"("p_costing_file_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.costing_files cf
    where cf.id = p_costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
        or (
          public.is_assigned_costing_file_viewer(cf.id)
          and cf.status::text in ('po_placed', 'completed')
        )
        or (
          public.can_customer_access_costing_file(cf.customer_group_id)
          and (
            lower(trim(cf.created_by_email)) = public.current_user_email()
            or cf.status = 'draft'
            or public.is_customer_group_admin_or_negotiator(cf.customer_group_id)
            or (
              cf.status = 'offered'
              and public.is_internal_costing_file_creator(cf.tenant_id, cf.created_by_email)
            )
          )
        )
      )
  );
$$;

ALTER FUNCTION "public"."can_view_costing_file_items"("p_costing_file_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."can_view_costing_item"("p_file_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.product_based_costing_files f
    where f.id = p_file_id
      and public.can_view_costing_internal(f.tenant_id)
  )
$$;

ALTER FUNCTION "public"."can_view_costing_item"("p_file_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."count_costing_files_for_actor"("p_tenant_id" bigint DEFAULT NULL::bigint, "p_customer_group_id" bigint DEFAULT NULL::bigint) RETURNS bigint
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select count(*)
  from public.costing_files cf
  where (
    p_tenant_id is not null
    and cf.tenant_id = p_tenant_id
    and (
      p_customer_group_id is null
      or cf.customer_group_id = p_customer_group_id
    )
    and (
      public.can_admin_manage_costing_file(cf.tenant_id)
      or public.can_staff_access_costing_file(cf.tenant_id)
    )
  )
  or (
    p_customer_group_id is not null
    and p_tenant_id is null
    and cf.customer_group_id = p_customer_group_id
    and public.can_customer_access_costing_file(cf.customer_group_id)
    and (
      cf.status = 'offered'
      or cf.created_by_email = public.current_user_email()
    )
  );
$$;

ALTER FUNCTION "public"."count_costing_files_for_actor"("p_tenant_id" bigint, "p_customer_group_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_costing_file"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_name" "text", "p_market" "text") RETURNS TABLE("id" bigint, "name" "text", "market" "text", "status" "public"."costing_file_status", "customer_group_id" bigint, "tenant_id" bigint, "created_by_email" "text", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if trim(coalesce(p_name, '')) = '' then
    raise exception 'Costing file name is required.';
  end if;

  if not exists (
    select 1
    from public.customer_groups cg
    where cg.id = p_customer_group_id
      and cg.tenant_id = p_tenant_id
  ) then
    raise exception 'Customer group does not belong to this tenant.';
  end if;

  if not (
    public.can_admin_manage_costing_file(p_tenant_id)
    or public.can_staff_access_costing_file(p_tenant_id)
    or public.can_customer_access_costing_file(p_customer_group_id)
  ) then
    raise exception 'You do not have permission to create this costing file.';
  end if;

  return query
    insert into public.costing_files (
      tenant_id,
      customer_group_id,
      name,
      market
    )
    values (
      p_tenant_id,
      p_customer_group_id,
      trim(p_name),
      nullif(trim(coalesce(p_market, '')), '')
    )
    returning
      id,
      name,
      market,
      status,
      customer_group_id,
      tenant_id,
      created_by_email,
      created_at,
      updated_at;
end;
$$;

ALTER FUNCTION "public"."create_costing_file"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_name" "text", "p_market" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_costing_file"("p_customer_group_id" bigint, "p_market" "text", "p_name" "text", "p_status" "public"."costing_file_status" DEFAULT 'draft'::"public"."costing_file_status", "p_tenant_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("id" bigint, "name" "text", "market" "text", "status" "public"."costing_file_status", "customer_group_id" bigint, "tenant_id" bigint, "created_by_email" "text", "default_shipment_id" bigint, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required.';
  end if;

  if trim(coalesce(p_name, '')) = '' then
    raise exception 'Costing file name is required.';
  end if;

  if not exists (
    select 1
    from public.customer_groups cg
    where cg.id = p_customer_group_id
      and cg.tenant_id = p_tenant_id
  ) then
    raise exception 'Customer group does not belong to this tenant.';
  end if;

  if not (
    public.can_admin_manage_costing_file(p_tenant_id)
    or public.can_staff_access_costing_file(p_tenant_id)
    or public.can_customer_access_costing_file(p_customer_group_id)
  ) then
    raise exception 'You do not have permission to create this costing file.';
  end if;

  return query
    insert into public.costing_files as cf (
      tenant_id,
      customer_group_id,
      name,
      market,
      status
    )
    values (
      p_tenant_id,
      p_customer_group_id,
      trim(p_name),
      nullif(trim(coalesce(p_market, '')), ''),
      coalesce(p_status, 'draft')
    )
    returning
      cf.id,
      cf.name,
      cf.market,
      cf.status,
      cf.customer_group_id,
      cf.tenant_id,
      cf.created_by_email,
      cf.default_shipment_id,
      cf.created_at,
      cf.updated_at;
end;
$$;

ALTER FUNCTION "public"."create_costing_file"("p_customer_group_id" bigint, "p_market" "text", "p_name" "text", "p_status" "public"."costing_file_status", "p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_costing_file_item_request"("p_costing_file_id" bigint, "p_website_url" "text", "p_quantity" integer) RETURNS TABLE("id" bigint, "costing_file_id" bigint, "website_url" "text", "quantity" integer, "status" "public"."costing_file_item_status", "created_by_email" "text", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with inserted as (
    insert into public.costing_file_items (
      costing_file_id,
      website_url,
      quantity
    )
    select
      cf.id,
      trim(p_website_url),
      p_quantity
    from public.costing_files cf
    where cf.id = p_costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
        or (
          cf.status = 'draft'
          and public.can_customer_access_costing_file(cf.customer_group_id)
          and lower(trim(cf.created_by_email)) = public.current_user_email()
        )
      )
    returning
      id,
      costing_file_id,
      website_url,
      quantity,
      status,
      created_by_email,
      created_at,
      updated_at
  )
  select *
  from inserted;
$$;

ALTER FUNCTION "public"."create_costing_file_item_request"("p_costing_file_id" bigint, "p_website_url" "text", "p_quantity" integer) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_costing_file_item_request"("p_costing_file_id" bigint, "p_website_url" "text", "p_quantity" integer, "p_item_type" "text" DEFAULT NULL::"text") RETURNS TABLE("id" bigint, "costing_file_id" bigint, "item_type" "text", "website_url" "text", "quantity" integer, "status" "public"."costing_file_item_status", "created_by_email" "text", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with inserted as (
    insert into public.costing_file_items (
      costing_file_id,
      item_type,
      website_url,
      quantity
    )
    select
      cf.id,
      nullif(trim(p_item_type), ''),
      trim(p_website_url),
      p_quantity
    from public.costing_files cf
    where cf.id = p_costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
        or (
          cf.status = 'draft'
          and public.can_customer_access_costing_file(cf.customer_group_id)
        )
      )
    returning
      id,
      costing_file_id,
      item_type,
      website_url,
      quantity,
      status,
      created_by_email,
      created_at,
      updated_at
  )
  select *
  from inserted;
$$;

ALTER FUNCTION "public"."create_costing_file_item_request"("p_costing_file_id" bigint, "p_website_url" "text", "p_quantity" integer, "p_item_type" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."current_costing_item_actor_role"("p_costing_file_id" bigint) RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select case
    when exists (
      select 1
      from public.costing_files cf
      where cf.id = p_costing_file_id
        and public.can_admin_manage_costing_file(cf.tenant_id)
    ) then 'admin'
    when exists (
      select 1
      from public.costing_files cf
      where cf.id = p_costing_file_id
        and public.can_staff_access_costing_file(cf.tenant_id)
    ) then 'staff'
    when exists (
      select 1
      from public.costing_files cf
      where cf.id = p_costing_file_id
        and public.can_customer_access_costing_file(cf.customer_group_id)
    ) then 'customer'
    else null
  end
$$;

ALTER FUNCTION "public"."current_costing_item_actor_role"("p_costing_file_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."enforce_costing_file_item_update_rules"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_actor_role text;
  v_file_status public.costing_file_status;
begin
  v_actor_role := public.current_costing_item_actor_role(old.costing_file_id);

  select cf.status
  into v_file_status
  from public.costing_files cf
  where cf.id = old.costing_file_id;

  if v_actor_role = 'admin' then
    return new;
  end if;

  if v_actor_role = 'staff' then
    if new.costing_file_id is distinct from old.costing_file_id
      or new.website_url is distinct from old.website_url
      or new.quantity is distinct from old.quantity
      or new.status is distinct from old.status
      or new.customer_profit_rate is distinct from old.customer_profit_rate
      or new.auxiliary_price_gbp is distinct from old.auxiliary_price_gbp
      or new.item_price_gbp is distinct from old.item_price_gbp
      or new.cargo_rate is distinct from old.cargo_rate
      or new.costing_price_gbp is distinct from old.costing_price_gbp
      or new.costing_price_bdt is distinct from old.costing_price_bdt
      or new.offer_price_bdt is distinct from old.offer_price_bdt
      or new.created_by_email is distinct from old.created_by_email
      or new.created_at is distinct from old.created_at
    then
      raise exception 'staff can update enrichment fields only';
    end if;

    return new;
  end if;

  if v_actor_role = 'customer' then
    if v_file_status = 'draft' then
      if new.costing_file_id is distinct from old.costing_file_id
        or new.status is distinct from old.status
        or new.name is distinct from old.name
        or new.image_url is distinct from old.image_url
        or new.product_weight is distinct from old.product_weight
        or new.package_weight is distinct from old.package_weight
        or new.price_in_web_gbp is distinct from old.price_in_web_gbp
        or new.delivery_price_gbp is distinct from old.delivery_price_gbp
        or new.auxiliary_price_gbp is distinct from old.auxiliary_price_gbp
        or new.item_price_gbp is distinct from old.item_price_gbp
        or new.cargo_rate is distinct from old.cargo_rate
        or new.costing_price_gbp is distinct from old.costing_price_gbp
        or new.costing_price_bdt is distinct from old.costing_price_bdt
        or new.offer_price_bdt is distinct from old.offer_price_bdt
        or new.offer_price_override_bdt is distinct from old.offer_price_override_bdt
        or new.customer_profit_rate is distinct from old.customer_profit_rate
        or new.created_by_email is distinct from old.created_by_email
        or new.created_at is distinct from old.created_at
      then
        raise exception 'customer can update website_url and quantity only while file is draft';
      end if;

      return new;
    end if;

    if v_file_status = 'offered' then
      if new.costing_file_id is distinct from old.costing_file_id
        or new.website_url is distinct from old.website_url
        or new.quantity is distinct from old.quantity
        or new.name is distinct from old.name
        or new.image_url is distinct from old.image_url
        or new.product_weight is distinct from old.product_weight
        or new.package_weight is distinct from old.package_weight
        or new.price_in_web_gbp is distinct from old.price_in_web_gbp
        or new.delivery_price_gbp is distinct from old.delivery_price_gbp
        or new.auxiliary_price_gbp is distinct from old.auxiliary_price_gbp
        or new.item_price_gbp is distinct from old.item_price_gbp
        or new.cargo_rate is distinct from old.cargo_rate
        or new.costing_price_gbp is distinct from old.costing_price_gbp
        or new.costing_price_bdt is distinct from old.costing_price_bdt
        or new.offer_price_bdt is distinct from old.offer_price_bdt
        or new.offer_price_override_bdt is distinct from old.offer_price_override_bdt
        or new.created_by_email is distinct from old.created_by_email
        or new.created_at is distinct from old.created_at
      then
        raise exception 'customer can update item status and customer_profit_rate only when file is offered';
      end if;

      return new;
    end if;

    raise exception 'customer cannot update costing file items in the current file status';
  end if;

  raise exception 'current user cannot update costing file items';
end;
$$;

ALTER FUNCTION "public"."enforce_costing_file_item_update_rules"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_costing_file_by_id"("p_id" bigint) RETURNS TABLE("id" bigint, "name" "text", "cargo_rate_1kg" numeric, "cargo_rate_2kg" numeric, "conversion_rate" numeric, "admin_profit_rate" numeric, "status" "public"."costing_file_status", "market" "text", "customer_group_id" bigint, "tenant_id" bigint, "created_by_email" "text", "default_shipment_id" bigint, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    cf.id,
    cf.name,
    cf.cargo_rate_1kg,
    cf.cargo_rate_2kg,
    cf.conversion_rate,
    cf.admin_profit_rate,
    cf.status,
    cf.market,
    cf.customer_group_id,
    cf.tenant_id,
    cf.created_by_email,
    cf.default_shipment_id,
    cf.created_at,
    cf.updated_at
  from public.costing_files cf
  where cf.id = p_id
    and public.can_view_costing_file(cf.id)
  limit 1;
$$;

ALTER FUNCTION "public"."get_costing_file_by_id"("p_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."grant_costing_file_viewer"("p_costing_file_id" bigint, "p_membership_id" bigint) RETURNS TABLE("costing_file_viewer_id" bigint, "costing_file_id" bigint, "membership_id" bigint, "name" "text", "email" "text", "role" "public"."app_role", "is_active" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;

ALTER FUNCTION "public"."grant_costing_file_viewer"("p_costing_file_id" bigint, "p_membership_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."is_assigned_costing_file_viewer"("p_costing_file_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.costing_file_viewers cfv
    inner join public.memberships m
      on m.id = cfv.membership_id
    where cfv.costing_file_id = p_costing_file_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role = 'viewer'
  );
$$;

ALTER FUNCTION "public"."is_assigned_costing_file_viewer"("p_costing_file_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."is_internal_costing_file_creator"("p_tenant_id" bigint, "p_email" "text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = lower(trim(coalesce(p_email, '')))
      and m.is_active = true
      and (
        (m.tenant_id = p_tenant_id and m.role in ('admin', 'staff'))
        or (m.tenant_id is null and m.role = 'superadmin')
      )
  );
$$;

ALTER FUNCTION "public"."is_internal_costing_file_creator"("p_tenant_id" bigint, "p_email" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_costing_file_items"("p_costing_file_id" bigint) RETURNS TABLE("id" bigint, "costing_file_id" bigint, "name" "text", "image_url" "text", "website_url" "text", "quantity" integer, "product_weight" integer, "package_weight" integer, "price_in_web_gbp" numeric, "delivery_price_gbp" numeric, "auxiliary_price_gbp" numeric, "item_price_gbp" numeric, "cargo_rate" numeric, "costing_price_gbp" numeric, "costing_price_bdt" integer, "offer_price_bdt" integer, "customer_profit_rate" numeric, "status" "public"."costing_file_item_status", "created_by_email" "text", "assigned_shipment_id" bigint, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    cfi.id,
    cfi.costing_file_id,
    cfi.name,
    cfi.image_url,
    cfi.website_url,
    cfi.quantity,
    cfi.product_weight,
    cfi.package_weight,
    cfi.price_in_web_gbp,
    cfi.delivery_price_gbp,
    cfi.auxiliary_price_gbp,
    cfi.item_price_gbp,
    cfi.cargo_rate,
    cfi.costing_price_gbp,
    cfi.costing_price_bdt,
    cfi.offer_price_bdt,
    cfi.customer_profit_rate,
    cfi.status,
    cfi.created_by_email,
    cfi.assigned_shipment_id,
    cfi.created_at,
    cfi.updated_at
  from public.costing_file_items cfi
  where cfi.costing_file_id = p_costing_file_id
    and public.can_view_costing_file(cfi.costing_file_id)
  order by cfi.id asc;
$$;

ALTER FUNCTION "public"."list_costing_file_items"("p_costing_file_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_costing_file_viewers"("p_costing_file_id" bigint) RETURNS TABLE("costing_file_viewer_id" bigint, "costing_file_id" bigint, "membership_id" bigint, "name" "text", "email" "text", "role" "public"."app_role", "is_active" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;

ALTER FUNCTION "public"."list_costing_file_viewers"("p_costing_file_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_costing_files_for_actor"("p_tenant_id" bigint DEFAULT NULL::bigint, "p_customer_group_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("id" bigint, "name" "text", "market" "text", "status" "public"."costing_file_status", "customer_group_id" bigint, "tenant_id" bigint, "created_by_email" "text", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    cf.id,
    cf.name,
    cf.market,
    cf.status,
    cf.customer_group_id,
    cf.tenant_id,
    cf.created_by_email,
    cf.created_at,
    cf.updated_at
  from public.costing_files cf
  where (
    p_tenant_id is not null
    and cf.tenant_id = p_tenant_id
    and (
      public.can_admin_manage_costing_file(cf.tenant_id)
      or public.can_staff_access_costing_file(cf.tenant_id)
    )
  )
  or (
    p_customer_group_id is not null
    and cf.customer_group_id = p_customer_group_id
    and public.can_customer_access_costing_file(cf.customer_group_id)
    and (
      cf.status = 'offered'
      or cf.created_by_email = public.current_user_email()
    )
  )
  order by cf.id desc;
$$;

ALTER FUNCTION "public"."list_costing_files_for_actor"("p_tenant_id" bigint, "p_customer_group_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_costing_files_for_actor"("p_tenant_id" bigint DEFAULT NULL::bigint, "p_customer_group_id" bigint DEFAULT NULL::bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  -- Get total count of matching files
  select count(*)
  into v_total_count
  from public.costing_files cf
  where (p_tenant_id is null or cf.tenant_id = p_tenant_id)
    and (p_customer_group_id is null or cf.customer_group_id = p_customer_group_id)
    and public.can_view_costing_file(cf.id);

  -- Get paginated records as a jsonb array
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      cf.id,
      cf.name,
      cf.market,
      cf.status,
      cf.customer_group_id,
      cf.tenant_id,
      cf.created_by_email,
      public.resolve_costing_file_creator_label(
        cf.tenant_id,
        cf.customer_group_id,
        cf.created_by_email
      ) as created_by_label,
      cf.default_shipment_id,
      cf.created_at,
      cf.updated_at
    from public.costing_files cf
    where (p_tenant_id is null or cf.tenant_id = p_tenant_id)
      and (p_customer_group_id is null or cf.customer_group_id = p_customer_group_id)
      and public.can_view_costing_file(cf.id)
    order by cf.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) r;

  -- Calculate total pages
  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::float / p_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total_count', v_total_count,
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', p_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$$;

ALTER FUNCTION "public"."list_costing_files_for_actor"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_page" integer, "p_page_size" integer) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."normalize_costing_file_item_fields"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
begin
  new.website_url := trim(coalesce(new.website_url, ''));

  if new.image_url is not null then
    new.image_url := nullif(trim(new.image_url), '');
  end if;

  if new.name is not null then
    new.name := nullif(trim(new.name), '');
  end if;

  if new.item_type is not null then
    new.item_type := nullif(trim(new.item_type), '');
  end if;

  if new.size is not null then
    new.size := nullif(trim(new.size), '');
  end if;

  if new.color is not null then
    new.color := nullif(trim(new.color), '');
  end if;

  if new.extra_information_1 is not null then
    new.extra_information_1 := nullif(trim(new.extra_information_1), '');
  end if;

  if new.extra_information_2 is not null then
    new.extra_information_2 := nullif(trim(new.extra_information_2), '');
  end if;

  return new;
end;
$$;

ALTER FUNCTION "public"."normalize_costing_file_item_fields"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."normalize_costing_file_market"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
begin
  if new.market is null then
    return new;
  end if;

  new.market := nullif(upper(trim(new.market)), '');
  return new;
end;
$$;

ALTER FUNCTION "public"."normalize_costing_file_market"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."normalize_costing_file_status_po_placed"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if new.status::text = 'completed' then
    new.status = 'po_placed'::public.costing_file_status;
  end if;

  return new;
end;
$$;

ALTER FUNCTION "public"."normalize_costing_file_status_po_placed"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."refresh_costing_file_item_calculations_for_file"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if
    new.cargo_rate_1kg is distinct from old.cargo_rate_1kg
    or new.cargo_rate_2kg is distinct from old.cargo_rate_2kg
    or new.conversion_rate is distinct from old.conversion_rate
    or new.admin_profit_rate is distinct from old.admin_profit_rate
  then
    update public.costing_file_items cfi
    set updated_at = now()
    where cfi.costing_file_id = new.id;
  end if;

  return new;
end;
$$;

ALTER FUNCTION "public"."refresh_costing_file_item_calculations_for_file"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."resolve_costing_file_creator_label"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_created_by_email" "text") RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select case
    when exists (
      select 1
      from public.memberships m
      where lower(trim(m.email)) = lower(trim(coalesce(p_created_by_email, '')))
        and m.is_active = true
        and (
          (m.tenant_id = p_tenant_id and m.role = 'admin')
          or (m.tenant_id is null and m.role = 'superadmin')
        )
    ) then 'admin'
    when exists (
      select 1
      from public.memberships m
      where lower(trim(m.email)) = lower(trim(coalesce(p_created_by_email, '')))
        and m.is_active = true
        and m.tenant_id = p_tenant_id
        and m.role = 'staff'
    ) then 'staff'
    else coalesce(
      (
        select cg.name
        from public.customer_group_members cgm
        inner join public.customer_groups cg
          on cg.id = cgm.customer_group_id
        where lower(trim(cgm.email)) = lower(trim(coalesce(p_created_by_email, '')))
          and cgm.is_active = true
          and cg.is_active = true
          and cgm.customer_group_id = p_customer_group_id
        limit 1
      ),
      'Unknown'
    )
  end;
$$;

ALTER FUNCTION "public"."resolve_costing_file_creator_label"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_created_by_email" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."revoke_costing_file_viewer"("p_costing_file_id" bigint, "p_membership_id" bigint) RETURNS TABLE("costing_file_viewer_id" bigint, "costing_file_id" bigint, "membership_id" bigint, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  delete from public.costing_file_viewers cfv
  using public.costing_files cf
  where cf.id = p_costing_file_id
    and cf.id = cfv.costing_file_id
    and cfv.membership_id = p_membership_id
    and public.can_manage_costing_file_viewers(cf.tenant_id)
  returning
    cfv.id as costing_file_viewer_id,
    cfv.costing_file_id,
    cfv.membership_id,
    cfv.created_at,
    cfv.updated_at;
$$;

ALTER FUNCTION "public"."revoke_costing_file_viewer"("p_costing_file_id" bigint, "p_membership_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_costing_file"("p_id" bigint, "p_name" "text" DEFAULT NULL::"text", "p_market" "text" DEFAULT NULL::"text", "p_customer_group_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("id" bigint, "name" "text", "cargo_rate_1kg" numeric, "cargo_rate_2kg" numeric, "conversion_rate" numeric, "admin_profit_rate" numeric, "status" "public"."costing_file_status", "market" "text", "customer_group_id" bigint, "tenant_id" bigint, "created_by_email" "text", "default_shipment_id" bigint, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with updated as (
    update public.costing_files cf
    set
      name = case
        when public.can_admin_manage_costing_file(cf.tenant_id)
          or (cf.status = 'draft' and public.can_customer_access_costing_file(cf.customer_group_id))
        then coalesce(trim(p_name), cf.name)
        else cf.name
      end,
      market = case
        when public.can_admin_manage_costing_file(cf.tenant_id)
          or (cf.status = 'draft' and public.can_customer_access_costing_file(cf.customer_group_id))
        then coalesce(trim(p_market), cf.market)
        else cf.market
      end,
      customer_group_id = case
        when public.can_admin_manage_costing_file(cf.tenant_id)
        then coalesce(p_customer_group_id, cf.customer_group_id)
        else cf.customer_group_id
      end
    where cf.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or (cf.status = 'draft' and public.can_customer_access_costing_file(cf.customer_group_id))
      )
    returning
      cf.id,
      cf.name,
      cf.cargo_rate_1kg,
      cf.cargo_rate_2kg,
      cf.conversion_rate,
      cf.admin_profit_rate,
      cf.status,
      cf.market,
      cf.customer_group_id,
      cf.tenant_id,
      cf.created_by_email,
      cf.default_shipment_id,
      cf.created_at,
      cf.updated_at
  )
  select *
  from updated;
$$;

ALTER FUNCTION "public"."update_costing_file"("p_id" bigint, "p_name" "text", "p_market" "text", "p_customer_group_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_costing_file_item_customer_profit"("p_id" bigint, "p_customer_profit_rate" numeric) RETURNS TABLE("id" bigint, "customer_profit_rate" numeric, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with updated as (
    update public.costing_file_items cfi
    set customer_profit_rate = p_customer_profit_rate
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_customer_access_costing_file(cf.customer_group_id)
      )
    returning
      cfi.id,
      cfi.customer_profit_rate,
      cfi.updated_at
  )
  select *
  from updated;
$$;

ALTER FUNCTION "public"."update_costing_file_item_customer_profit"("p_id" bigint, "p_customer_profit_rate" numeric) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_costing_file_item_enrichment"("p_id" bigint, "p_name" "text" DEFAULT NULL::"text", "p_image_url" "text" DEFAULT NULL::"text", "p_product_weight" integer DEFAULT NULL::integer, "p_package_weight" integer DEFAULT NULL::integer, "p_price_in_web_gbp" numeric DEFAULT NULL::numeric, "p_delivery_price_gbp" numeric DEFAULT NULL::numeric) RETURNS TABLE("id" bigint, "costing_file_id" bigint, "name" "text", "image_url" "text", "product_weight" integer, "package_weight" integer, "price_in_web_gbp" numeric, "delivery_price_gbp" numeric, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with updated as (
    update public.costing_file_items cfi
    set
      name = coalesce(trim(p_name), cfi.name),
      image_url = coalesce(trim(p_image_url), cfi.image_url),
      product_weight = coalesce(p_product_weight, cfi.product_weight),
      package_weight = coalesce(p_package_weight, cfi.package_weight),
      price_in_web_gbp = coalesce(p_price_in_web_gbp, cfi.price_in_web_gbp),
      delivery_price_gbp = coalesce(p_delivery_price_gbp, cfi.delivery_price_gbp)
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
      )
    returning
      cfi.id,
      cfi.costing_file_id,
      cfi.name,
      cfi.image_url,
      cfi.product_weight,
      cfi.package_weight,
      cfi.price_in_web_gbp,
      cfi.delivery_price_gbp,
      cfi.updated_at
  )
  select *
  from updated;
$$;

ALTER FUNCTION "public"."update_costing_file_item_enrichment"("p_id" bigint, "p_name" "text", "p_image_url" "text", "p_product_weight" integer, "p_package_weight" integer, "p_price_in_web_gbp" numeric, "p_delivery_price_gbp" numeric) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_costing_file_item_enrichment"("p_id" bigint, "p_name" "text", "p_item_type" "text", "p_image_url" "text", "p_product_weight" integer, "p_package_weight" integer, "p_price_in_web_gbp" numeric, "p_delivery_price_gbp" numeric) RETURNS TABLE("id" bigint, "costing_file_id" bigint, "name" "text", "image_url" "text", "website_url" "text", "quantity" integer, "product_weight" integer, "package_weight" integer, "price_in_web_gbp" numeric, "delivery_price_gbp" numeric, "auxiliary_price_gbp" numeric, "item_price_gbp" numeric, "cargo_rate" numeric, "costing_price_gbp" numeric, "costing_price_bdt" integer, "offer_price_bdt" integer, "customer_profit_rate" numeric, "status" "public"."costing_file_item_status", "created_by_email" "text", "assigned_shipment_id" bigint, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  return query
    with updated as (
      update public.costing_file_items cfi
      set
        name = coalesce(trim(p_name), cfi.name),
        item_type = coalesce(trim(p_item_type), cfi.item_type),
        image_url = coalesce(trim(p_image_url), cfi.image_url),
        product_weight = coalesce(p_product_weight, cfi.product_weight),
        package_weight = coalesce(p_package_weight, cfi.package_weight),
        price_in_web_gbp = coalesce(p_price_in_web_gbp, cfi.price_in_web_gbp),
        delivery_price_gbp = coalesce(p_delivery_price_gbp, cfi.delivery_price_gbp)
      where cfi.id = p_id
        and public.can_admin_manage_costing_file((select cf.tenant_id from public.costing_files cf where cf.id = cfi.costing_file_id))
      returning
        cfi.id,
        cfi.costing_file_id,
        cfi.name,
        cfi.image_url,
        cfi.website_url,
        cfi.quantity,
        cfi.product_weight,
        cfi.package_weight,
        cfi.price_in_web_gbp,
        cfi.delivery_price_gbp,
        cfi.auxiliary_price_gbp,
        cfi.item_price_gbp,
        cfi.cargo_rate,
        cfi.costing_price_gbp,
        cfi.costing_price_bdt,
        cfi.offer_price_bdt,
        cfi.customer_profit_rate,
        cfi.status,
        cfi.created_by_email,
        cfi.assigned_shipment_id,
        cfi.created_at,
        cfi.updated_at
    )
    select *
    from updated;
end;
$$;

ALTER FUNCTION "public"."update_costing_file_item_enrichment"("p_id" bigint, "p_name" "text", "p_item_type" "text", "p_image_url" "text", "p_product_weight" integer, "p_package_weight" integer, "p_price_in_web_gbp" numeric, "p_delivery_price_gbp" numeric) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_costing_file_item_offer"("p_id" bigint, "p_auxiliary_price_gbp" numeric DEFAULT NULL::numeric, "p_item_price_gbp" numeric DEFAULT NULL::numeric, "p_cargo_rate" numeric DEFAULT NULL::numeric, "p_costing_price_gbp" numeric DEFAULT NULL::numeric, "p_costing_price_bdt" integer DEFAULT NULL::integer, "p_offer_price_override_bdt" integer DEFAULT NULL::integer) RETURNS TABLE("id" bigint, "auxiliary_price_gbp" numeric, "item_price_gbp" numeric, "cargo_rate" numeric, "costing_price_gbp" numeric, "costing_price_bdt" integer, "offer_price_override_bdt" integer, "offer_price_bdt" integer, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with updated as (
    update public.costing_file_items cfi
    set
      auxiliary_price_gbp = coalesce(p_auxiliary_price_gbp, cfi.auxiliary_price_gbp),
      item_price_gbp = coalesce(p_item_price_gbp, cfi.item_price_gbp),
      cargo_rate = coalesce(p_cargo_rate, cfi.cargo_rate),
      costing_price_gbp = coalesce(p_costing_price_gbp, cfi.costing_price_gbp),
      costing_price_bdt = coalesce(p_costing_price_bdt, cfi.costing_price_bdt),
      offer_price_override_bdt = p_offer_price_override_bdt
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.id = p_id
      and public.can_admin_manage_costing_file(cf.tenant_id)
    returning
      cfi.id,
      cfi.auxiliary_price_gbp,
      cfi.item_price_gbp,
      cfi.cargo_rate,
      cfi.costing_price_gbp,
      cfi.costing_price_bdt,
      cfi.offer_price_override_bdt,
      cfi.offer_price_bdt,
      cfi.updated_at
  )
  select *
  from updated;
$$;

ALTER FUNCTION "public"."update_costing_file_item_offer"("p_id" bigint, "p_auxiliary_price_gbp" numeric, "p_item_price_gbp" numeric, "p_cargo_rate" numeric, "p_costing_price_gbp" numeric, "p_costing_price_bdt" integer, "p_offer_price_override_bdt" integer) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_costing_file_item_status"("p_id" bigint, "p_status" "public"."costing_file_item_status") RETURNS TABLE("id" bigint, "status" "public"."costing_file_item_status", "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with updated as (
    update public.costing_file_items cfi
    set status = p_status
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or (
          cf.status = 'offered'
          and public.can_customer_access_costing_file(cf.customer_group_id)
        )
      )
    returning
      cfi.id,
      cfi.status,
      cfi.updated_at
  )
  select *
  from updated;
$$;

ALTER FUNCTION "public"."update_costing_file_item_status"("p_id" bigint, "p_status" "public"."costing_file_item_status") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_costing_file_items_customer_profit"("p_costing_file_id" bigint, "p_customer_profit_rate" numeric) RETURNS TABLE("id" bigint, "customer_profit_rate" numeric, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with updated as (
    update public.costing_file_items cfi
    set customer_profit_rate = p_customer_profit_rate
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.costing_file_id = p_costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_customer_access_costing_file(cf.customer_group_id)
      )
    returning
      cfi.id,
      cfi.customer_profit_rate,
      cfi.updated_at
  )
  select *
  from updated;
$$;

ALTER FUNCTION "public"."update_costing_file_items_customer_profit"("p_costing_file_id" bigint, "p_customer_profit_rate" numeric) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_costing_file_pricing"("p_id" bigint, "p_cargo_rate_1kg" numeric DEFAULT NULL::numeric, "p_cargo_rate_2kg" numeric DEFAULT NULL::numeric, "p_conversion_rate" numeric DEFAULT NULL::numeric, "p_admin_profit_rate" numeric DEFAULT NULL::numeric) RETURNS TABLE("id" bigint, "cargo_rate_1kg" numeric, "cargo_rate_2kg" numeric, "conversion_rate" numeric, "admin_profit_rate" numeric, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with updated as (
    update public.costing_files cf
    set
      cargo_rate_1kg = coalesce(p_cargo_rate_1kg, cf.cargo_rate_1kg),
      cargo_rate_2kg = coalesce(p_cargo_rate_2kg, cf.cargo_rate_2kg),
      conversion_rate = coalesce(p_conversion_rate, cf.conversion_rate),
      admin_profit_rate = coalesce(p_admin_profit_rate, cf.admin_profit_rate)
    where cf.id = p_id
      and public.can_admin_manage_costing_file(cf.tenant_id)
    returning
      cf.id,
      cf.cargo_rate_1kg,
      cf.cargo_rate_2kg,
      cf.conversion_rate,
      cf.admin_profit_rate,
      cf.updated_at
  )
  select *
  from updated;
$$;

ALTER FUNCTION "public"."update_costing_file_pricing"("p_id" bigint, "p_cargo_rate_1kg" numeric, "p_cargo_rate_2kg" numeric, "p_conversion_rate" numeric, "p_admin_profit_rate" numeric) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_costing_file_status"("p_id" bigint, "p_status" "public"."costing_file_status") RETURNS TABLE("id" bigint, "status" "public"."costing_file_status", "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with updated as (
    update public.costing_files cf
    set status = p_status
    where cf.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or (
          public.can_staff_access_costing_file(cf.tenant_id)
          and cf.status = 'customer_submitted'
          and p_status = 'in_review'
        )
        or (
          public.can_customer_access_costing_file(cf.customer_group_id)
          and (
            (cf.status = 'draft' and p_status = 'customer_submitted')
            or (cf.status = 'offered' and p_status = 'accepted')
          )
        )
      )
    returning
      cf.id,
      cf.status,
      cf.updated_at
  )
  select *
  from updated;
$$;

ALTER FUNCTION "public"."update_costing_file_status"("p_id" bigint, "p_status" "public"."costing_file_status") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."validate_costing_file_customer_group"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
declare
  v_group_tenant_id bigint;
begin
  select cg.tenant_id
  into v_group_tenant_id
  from public.customer_groups cg
  where cg.id = new.customer_group_id;

  if v_group_tenant_id is null then
    raise exception 'customer_group_id % does not exist', new.customer_group_id;
  end if;

  if v_group_tenant_id <> new.tenant_id then
    raise exception 'customer_group_id % does not belong to tenant_id %', new.customer_group_id, new.tenant_id;
  end if;

  return new;
end;
$$;

ALTER FUNCTION "public"."validate_costing_file_customer_group"() OWNER TO "postgres";

CREATE OR REPLACE TRIGGER "trg_costing_file_items_apply_calculations" BEFORE INSERT OR UPDATE ON "public"."costing_file_items" FOR EACH ROW EXECUTE FUNCTION "public"."apply_costing_item_calculations"();

CREATE OR REPLACE TRIGGER "trg_costing_file_items_enforce_update_rules" BEFORE UPDATE ON "public"."costing_file_items" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_costing_file_item_update_rules"();

CREATE OR REPLACE TRIGGER "trg_costing_file_items_normalize_fields" BEFORE INSERT OR UPDATE ON "public"."costing_file_items" FOR EACH ROW EXECUTE FUNCTION "public"."normalize_costing_file_item_fields"();

CREATE OR REPLACE TRIGGER "trg_costing_file_items_updated_at" BEFORE UPDATE ON "public"."costing_file_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_costing_file_viewers_updated_at" BEFORE UPDATE ON "public"."costing_file_viewers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_costing_files_normalize_market" BEFORE INSERT OR UPDATE ON "public"."costing_files" FOR EACH ROW EXECUTE FUNCTION "public"."normalize_costing_file_market"();

CREATE OR REPLACE TRIGGER "trg_costing_files_normalize_status_po_placed" BEFORE INSERT OR UPDATE ON "public"."costing_files" FOR EACH ROW EXECUTE FUNCTION "public"."normalize_costing_file_status_po_placed"();

CREATE OR REPLACE TRIGGER "trg_costing_files_refresh_item_calculations" AFTER UPDATE ON "public"."costing_files" FOR EACH ROW EXECUTE FUNCTION "public"."refresh_costing_file_item_calculations_for_file"();

CREATE OR REPLACE TRIGGER "trg_costing_files_updated_at" BEFORE UPDATE ON "public"."costing_files" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_costing_files_validate_customer_group" BEFORE INSERT OR UPDATE ON "public"."costing_files" FOR EACH ROW EXECUTE FUNCTION "public"."validate_costing_file_customer_group"();
