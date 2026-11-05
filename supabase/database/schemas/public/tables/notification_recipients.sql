CREATE TABLE public.notification_recipients (
  id              uuid                     DEFAULT gen_random_uuid() NOT NULL,
  notification_id uuid                     NOT NULL,
  user_id         uuid                     NOT NULL,
  read_at         timestamp with time zone,
  created_at      timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX notification_recipients_user_read_created_idx ON public.notification_recipients (user_id, read_at, created_at DESC);

CREATE INDEX notification_recipients_notification_id_idx ON public.notification_recipients (notification_id);

CREATE TRIGGER trg_notification_recipients_dispatch
  AFTER INSERT ON public.notification_recipients
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notification_recipients_dispatch();

CREATE POLICY notification_recipients_select_own ON public.notification_recipients
  FOR SELECT
  USING ((user_id = ( SELECT auth.uid() AS uid)));

CREATE POLICY notification_recipients_update_own ON public.notification_recipients
  FOR UPDATE
  USING ((user_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));

ALTER TABLE public.notification_recipients
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.notification_recipients
  REPLICA IDENTITY FULL;

ALTER TABLE public.notification_recipients
  ADD CONSTRAINT notification_recipients_pkey PRIMARY KEY (id);

ALTER TABLE public.notification_recipients
  ADD CONSTRAINT notification_recipients_unique_user UNIQUE (notification_id, user_id);

ALTER TABLE public.notification_recipients
  ADD CONSTRAINT notification_recipients_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.notification_recipients
  ADD CONSTRAINT notification_recipients_notification_id_fkey FOREIGN KEY (notification_id) REFERENCES public.notifications(id) ON DELETE CASCADE;

GRANT ALL ON public.notification_recipients TO anon;

GRANT ALL ON public.notification_recipients TO authenticated;

GRANT ALL ON public.notification_recipients TO service_role;