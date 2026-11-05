CREATE FUNCTION public.normalize_membership_email()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  new.email := lower(trim(coalesce(new.email, '')));

  if new.email = '' then
    raise exception 'membership email cannot be empty';
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.normalize_membership_email() TO anon;

GRANT ALL ON FUNCTION public.normalize_membership_email() TO authenticated;

GRANT ALL ON FUNCTION public.normalize_membership_email() TO service_role;