-- Enable Realtime on notification_recipients for in-app bell updates.

ALTER TABLE public.notification_recipients REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notification_recipients'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notification_recipients;
  END IF;
END
$$;
