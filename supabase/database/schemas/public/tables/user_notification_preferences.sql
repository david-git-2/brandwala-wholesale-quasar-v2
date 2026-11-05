CREATE TABLE public.user_notification_preferences (
  user_id           uuid                     NOT NULL,
  channel_telegram  boolean                  DEFAULT false NOT NULL,
  channel_push      boolean                  DEFAULT false NOT NULL,
  channel_email     boolean                  DEFAULT false NOT NULL,
  event_preferences jsonb                    DEFAULT '{}'::jsonb NOT NULL,
  updated_at        timestamp with time zone DEFAULT now() NOT NULL
);

CREATE POLICY user_notification_preferences_delete_own ON public.user_notification_preferences
  FOR DELETE
  TO authenticated
  USING ((user_id = ( SELECT auth.uid() AS uid)));

CREATE POLICY user_notification_preferences_insert_own ON public.user_notification_preferences
  FOR INSERT
  TO authenticated
  WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));

CREATE POLICY user_notification_preferences_select_own ON public.user_notification_preferences
  FOR SELECT
  TO authenticated
  USING ((user_id = ( SELECT auth.uid() AS uid)));

CREATE POLICY user_notification_preferences_update_own ON public.user_notification_preferences
  FOR UPDATE
  TO authenticated
  USING ((user_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));

ALTER TABLE public.user_notification_preferences
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_notification_preferences
  ADD CONSTRAINT user_notification_preferences_pkey PRIMARY KEY (user_id);

ALTER TABLE public.user_notification_preferences
  ADD CONSTRAINT user_notification_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

GRANT ALL ON public.user_notification_preferences TO anon;

GRANT ALL ON public.user_notification_preferences TO authenticated;

GRANT ALL ON public.user_notification_preferences TO service_role;