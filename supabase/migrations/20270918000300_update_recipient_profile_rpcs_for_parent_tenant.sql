-- Migration: 20270918000300_update_recipient_profile_rpcs_for_parent_tenant.sql
-- Update recipient profile RPCs to match across parent_tenant_id and return parent_tenant_id

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
  where (parent_tenant_id = v_parent_id or (parent_tenant_id is null and tenant_id = v_parent_id) or tenant_id = p_tenant_id)
    and phone = v_phone
  order by (parent_tenant_id = v_parent_id) desc, updated_at desc
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
    'parent_tenant_id', v_row.parent_tenant_id,
    'created_at', v_row.created_at,
    'updated_at', v_row.updated_at
  );
end;
$$;

ALTER FUNCTION "public"."get_recipient_profile_by_phone"("p_tenant_id" bigint, "p_phone" "text") OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."get_recipient_profile_by_phone"("p_tenant_id" bigint, "p_phone" "text") TO "authenticated";


CREATE OR REPLACE FUNCTION "public"."upsert_recipient_profile_by_phone"(
  "p_tenant_id" bigint,
  "p_name" "text",
  "p_phone" "text",
  "p_secondary_phone" "text" DEFAULT NULL::"text",
  "p_address" "text" DEFAULT NULL::"text",
  "p_district" "text" DEFAULT NULL::"text",
  "p_thana" "text" DEFAULT NULL::"text"
) RETURNS "jsonb"
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

  select * into v_row
  from public.recipient_profiles
  where (parent_tenant_id = v_parent_id or (parent_tenant_id is null and tenant_id = v_parent_id) or tenant_id = p_tenant_id)
    and phone = v_phone
  order by (parent_tenant_id = v_parent_id) desc, updated_at desc
  limit 1
  for update;

  if v_row.id is null then
    insert into public.recipient_profiles (
      tenant_id, parent_tenant_id, name, phone, secondary_phone, address, district, thana, addresses
    )
    values (
      p_tenant_id, v_parent_id, v_name, v_phone, v_secondary, v_address, v_district, v_thana,
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
      parent_tenant_id = coalesce(parent_tenant_id, v_parent_id),
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
    'parent_tenant_id', v_row.parent_tenant_id,
    'created_at', v_row.created_at,
    'updated_at', v_row.updated_at
  );
end;
$$;

ALTER FUNCTION "public"."upsert_recipient_profile_by_phone"("p_tenant_id" bigint, "p_name" "text", "p_phone" "text", "p_secondary_phone" "text", "p_address" "text", "p_district" "text", "p_thana" "text") OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."upsert_recipient_profile_by_phone"("p_tenant_id" bigint, "p_name" "text", "p_phone" "text", "p_secondary_phone" "text", "p_address" "text", "p_district" "text", "p_thana" "text") TO "authenticated";
