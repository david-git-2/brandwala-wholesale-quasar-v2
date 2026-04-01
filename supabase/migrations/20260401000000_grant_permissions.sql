-- =========================================================
-- Grant permissions on memberships table
-- =========================================================

grant all on table public.memberships to authenticated;
grant all on sequence public.memberships_id_seq to authenticated;

-- Also ensure other related tables have proper grants for authenticated users
grant all on table public.tenants to authenticated;
grant all on sequence public.tenants_id_seq to authenticated;

grant all on table public.profiles to authenticated;
grant all on sequence public.profiles_id_seq to authenticated;

grant all on table public.modules to authenticated;
grant all on sequence public.modules_id_seq to authenticated;

grant all on table public.tenant_modules to authenticated;
grant all on sequence public.tenant_modules_id_seq to authenticated;
