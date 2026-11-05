CREATE FUNCTION public.upsert_recipient_profile_and_address (
  p_tenant_id       bigint,
  p_name            text,
  p_phone           text,
  p_phone_secondary text   DEFAULT NULL::text,
  p_address         text   DEFAULT NULL::text,
  p_district        text   DEFAULT NULL::text,
  p_thana           text   DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  return public.upsert_recipient_profile_by_phone(
    p_tenant_id => p_tenant_id,
    p_name => p_name,
    p_phone => p_phone,
    p_secondary_phone => p_phone_secondary,
    p_address => p_address,
    p_district => p_district,
    p_thana => p_thana
  );
end;
$function$;

GRANT ALL ON FUNCTION public.upsert_recipient_profile_and_address(bigint, text, text, text, text, text, text) TO anon;

GRANT ALL ON FUNCTION public.upsert_recipient_profile_and_address(bigint, text, text, text, text, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_recipient_profile_and_address(bigint, text, text, text, text, text, text) TO service_role;