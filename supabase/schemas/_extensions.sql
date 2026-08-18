-- Extensions required to replay supabase/schemas/public.sql on a shadow DB.
-- `supabase db dump --schema public` does not emit CREATE EXTENSION.
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;
