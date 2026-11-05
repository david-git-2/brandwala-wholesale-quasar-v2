CREATE FUNCTION public.auth_investor_id()
  RETURNS bigint
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_investor_id bigint;
begin
  select m.investor_id into v_investor_id
  from public.memberships m
  inner join public.investors i
    on i.id = m.investor_id
    and i.is_active = true
  where public.membership_email_matches_current_user(m.email)
    and m.is_active = true
  order by case when m.role = 'investor'::public.app_role then 0 else 1 end
  limit 1;

  return v_investor_id;
end;
$function$;

GRANT ALL ON FUNCTION public.auth_investor_id() TO anon;

GRANT ALL ON FUNCTION public.auth_investor_id() TO authenticated;

GRANT ALL ON FUNCTION public.auth_investor_id() TO service_role;