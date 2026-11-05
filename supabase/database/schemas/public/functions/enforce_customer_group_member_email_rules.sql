CREATE FUNCTION public.enforce_customer_group_member_email_rules()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO 'public'
  AS $function$
declare
  v_normalized_email text;
begin
  v_normalized_email := lower(trim(new.email));
  new.email := v_normalized_email;

  if exists (
    select 1
    from public.customer_group_members cgm
    where cgm.customer_group_id = new.customer_group_id
      and lower(trim(cgm.email)) = v_normalized_email
      and cgm.id <> coalesce(new.id, -1)
  ) then
    raise exception 'This email is already used in this group';
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.enforce_customer_group_member_email_rules() TO anon;

GRANT ALL ON FUNCTION public.enforce_customer_group_member_email_rules() TO authenticated;

GRANT ALL ON FUNCTION public.enforce_customer_group_member_email_rules() TO service_role;