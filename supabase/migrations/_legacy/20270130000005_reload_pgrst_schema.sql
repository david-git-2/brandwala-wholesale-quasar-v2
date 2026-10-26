-- Fix Postgres 42703 error: reload PostgREST schema cache

NOTIFY pgrst, 'reload schema';
