-- Migration: 20270918000400_recipient_profiles_nullable_tenant_id.sql
-- Allow tenant_id to be nullable for parent-created recipient profiles and enforce parent_tenant_id

ALTER TABLE "public"."recipient_profiles"
  ALTER COLUMN "tenant_id" DROP NOT NULL;

ALTER TABLE "public"."recipient_profiles"
  DROP CONSTRAINT IF EXISTS "recipient_profiles_tenant_id_fkey";

ALTER TABLE "public"."recipient_profiles"
  ADD CONSTRAINT "recipient_profiles_tenant_id_fkey"
  FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE SET NULL;

-- Update index for parent_tenant_id queries
CREATE INDEX IF NOT EXISTS "recipient_profiles_parent_tenant_id_idx"
  ON "public"."recipient_profiles" USING btree ("parent_tenant_id");

-- Update upsert function to store NULL for tenant_id when called with parent_tenant_id
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

  if p_tenant_id = v_parent_id then
    v_insert_tenant_id := null;
  else
    v_insert_tenant_id := p_tenant_id;
  end if;

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
      v_insert_tenant_id, v_parent_id, v_name, v_phone, v_secondary, v_address, v_district, v_thana,
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
