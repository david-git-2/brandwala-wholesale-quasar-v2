-- Notifications domain — types

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'notification_audience'
  ) THEN
    CREATE TYPE public.notification_audience AS ENUM (
      'child_only',
      'parent_only',
      'child_and_parent',
      'assignee_only'
    );
  END IF;
END
$$;

ALTER TYPE public.notification_audience OWNER TO postgres;
