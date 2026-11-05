CREATE TABLE public.notification_delivery_log (
  id              uuid                     DEFAULT gen_random_uuid() NOT NULL,
  notification_id uuid                     NOT NULL,
  user_id         uuid                     NOT NULL,
  channel         text                     NOT NULL,
  status          text                     NOT NULL,
  error_message   text,
  created_at      timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX notification_delivery_log_notification_id_idx ON public.notification_delivery_log (notification_id);

CREATE INDEX notification_delivery_log_user_created_idx ON public.notification_delivery_log (user_id, created_at DESC);

CREATE POLICY notification_delivery_log_select_own ON public.notification_delivery_log
  FOR SELECT
  TO authenticated
  USING ((user_id = ( SELECT auth.uid() AS uid)));

ALTER TABLE public.notification_delivery_log
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.notification_delivery_log
  ADD CONSTRAINT notification_delivery_log_channel_check CHECK (channel = ANY (ARRAY['telegram'::text, 'push'::text, 'email'::text]));

ALTER TABLE public.notification_delivery_log
  ADD CONSTRAINT notification_delivery_log_pkey PRIMARY KEY (id);

ALTER TABLE public.notification_delivery_log
  ADD CONSTRAINT notification_delivery_log_status_check CHECK (status = ANY (ARRAY['sent'::text, 'failed'::text]));

ALTER TABLE public.notification_delivery_log
  ADD CONSTRAINT notification_delivery_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.notification_delivery_log
  ADD CONSTRAINT notification_delivery_log_notification_id_fkey FOREIGN KEY (notification_id) REFERENCES public.notifications(id) ON DELETE CASCADE;

GRANT ALL ON public.notification_delivery_log TO anon;

GRANT ALL ON public.notification_delivery_log TO authenticated;

GRANT ALL ON public.notification_delivery_log TO service_role;