CREATE FUNCTION public.find_customer_admin_email_conflict (
  p_tenant_id                  bigint,
  p_email                      text,
  p_exclude_billing_profile_id bigint DEFAULT NULL::bigint,
  p_exclude_member_id          bigint DEFAULT NULL::bigint,
  p_exclude_customer_group_id  bigint DEFAULT NULL::bigint
)
  RETURNS text
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  -- Phone is the company key. Email is unique per group only.
  return null;
end;
$function$;

GRANT ALL ON FUNCTION public.find_customer_admin_email_conflict(bigint, text, bigint, bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.find_customer_admin_email_conflict(bigint, text, bigint, bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.find_customer_admin_email_conflict(bigint, text, bigint, bigint, bigint) TO service_role;