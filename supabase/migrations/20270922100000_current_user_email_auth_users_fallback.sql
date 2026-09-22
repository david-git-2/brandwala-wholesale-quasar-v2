-- JWT often omits email on prod Google tokens. Fall back to auth.users via auth.uid().

create or replace function public.current_user_email()
returns text
language sql
stable
security definer
set search_path to 'public', 'auth'
as $$
  select lower(trim(coalesce(
    nullif(auth.jwt() ->> 'email', ''),
    (select u.email from auth.users u where u.id = auth.uid())
  )));
$$;

revoke all on function public.current_user_email() from public;
grant execute on function public.current_user_email() to authenticated;
