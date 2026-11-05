CREATE FUNCTION public.upsert_profile_for_party (
  p_parent_tenant_id   bigint,
  p_profile_type       public.profile_party_type,
  p_subject_id         bigint,
  p_name               text,
  p_email              text                      DEFAULT NULL::text,
  p_phone              text                      DEFAULT NULL::text,
  p_phone_country_code text                      DEFAULT '+880'::text,
  p_address            text                      DEFAULT NULL::text,
  p_is_phone_unique    boolean                   DEFAULT true,
  p_accent_color       text                      DEFAULT NULL::text,
  p_is_active          boolean                   DEFAULT true,
  p_deleted_at         timestamp with time zone  DEFAULT NULL::timestamp WITH time zone
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_profile_id bigint;
  v_phone_unique boolean;
begin
  if p_parent_tenant_id is null or p_subject_id is null then
    return null;
  end if;

  if nullif(btrim(coalesce(p_name, '')), '') is null then
    raise exception 'profile name is required';
  end if;

  v_phone_unique := coalesce(p_is_phone_unique, true);
  if p_phone is null or btrim(p_phone) = '' then
    v_phone_unique := false;
  end if;

  insert into public.profiles (
    parent_tenant_id,
    profile_type,
    subject_id,
    name,
    email,
    phone,
    phone_country_code,
    address,
    is_phone_unique,
    accent_color,
    is_active,
    deleted_at
  )
  values (
    p_parent_tenant_id,
    p_profile_type,
    p_subject_id,
    btrim(p_name),
    nullif(btrim(coalesce(p_email, '')), ''),
    nullif(btrim(coalesce(p_phone, '')), ''),
    coalesce(nullif(btrim(coalesce(p_phone_country_code, '')), ''), '+880'),
    nullif(btrim(coalesce(p_address, '')), ''),
    v_phone_unique,
    nullif(btrim(coalesce(p_accent_color, '')), ''),
    coalesce(p_is_active, true),
    p_deleted_at
  )
  on conflict (parent_tenant_id, profile_type, subject_id) do update set
    name = excluded.name,
    email = excluded.email,
    phone = excluded.phone,
    phone_country_code = excluded.phone_country_code,
    address = excluded.address,
    is_phone_unique = excluded.is_phone_unique,
    accent_color = coalesce(excluded.accent_color, profiles.accent_color),
    is_active = excluded.is_active,
    deleted_at = excluded.deleted_at,
    updated_at = now()
  returning id into v_profile_id;

  return v_profile_id;
end;
$function$;

GRANT ALL ON FUNCTION public.upsert_profile_for_party(bigint, public.profile_party_type, bigint, text, text, text, text, text, boolean, text, boolean, timestamp
  WITH time zone) TO anon;

GRANT ALL ON FUNCTION public.upsert_profile_for_party(bigint, public.profile_party_type, bigint, text, text, text, text, text, boolean, text, boolean, timestamp
  WITH time zone) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_profile_for_party(bigint, public.profile_party_type, bigint, text, text, text, text, text, boolean, text, boolean, timestamp
  WITH time zone) TO service_role;