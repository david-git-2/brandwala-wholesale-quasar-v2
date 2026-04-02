-- =========================================================
-- Drop legacy profiles table and helper
-- =========================================================

drop function if exists public.current_profile_id();

drop trigger if exists trg_profiles_updated_at on public.profiles;
drop index if exists public.profiles_auth_user_id_idx;
drop table if exists public.profiles;
