CREATE FUNCTION public.membership_email_matches_current_user (
  p_membership_email text
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public', 'auth'
  AS $function$
  select case
    when p_membership_email is null or trim(p_membership_email) = '' then false
    else lower(trim(p_membership_email)) = public.current_user_email()
      or (
        auth.uid() is not null
        and exists (
          select 1
          from auth.users u
          where u.id = auth.uid()
            and lower(trim(u.email)) = public.current_user_email()
            and lower(trim(u.email)) like lower(trim(p_membership_email)) || '%'
        )
      )
  end;
$function$;

GRANT ALL ON FUNCTION public.membership_email_matches_current_user(text) TO anon;

GRANT ALL ON FUNCTION public.membership_email_matches_current_user(text) TO authenticated;

GRANT ALL ON FUNCTION public.membership_email_matches_current_user(text) TO service_role;