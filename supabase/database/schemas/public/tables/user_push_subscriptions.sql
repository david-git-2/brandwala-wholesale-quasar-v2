CREATE TABLE public.user_push_subscriptions (
  id           uuid                     DEFAULT gen_random_uuid() NOT NULL,
  user_id      uuid                     NOT NULL,
  fcm_token    text                     NOT NULL,
  platform     text                     DEFAULT 'web'::text NOT NULL,
  created_at   timestamp with time zone DEFAULT now() NOT NULL,
  last_used_at timestamp with time zone
);

CREATE INDEX user_push_subscriptions_user_id_idx ON public.user_push_subscriptions (user_id);

CREATE POLICY user_push_subscriptions_delete_own ON public.user_push_subscriptions
  FOR DELETE
  TO authenticated
  USING ((user_id = ( SELECT auth.uid() AS uid)));

CREATE POLICY user_push_subscriptions_insert_own ON public.user_push_subscriptions
  FOR INSERT
  TO authenticated
  WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));

CREATE POLICY user_push_subscriptions_select_own ON public.user_push_subscriptions
  FOR SELECT
  TO authenticated
  USING ((user_id = ( SELECT auth.uid() AS uid)));

CREATE POLICY user_push_subscriptions_update_own ON public.user_push_subscriptions
  FOR UPDATE
  TO authenticated
  USING ((user_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));

ALTER TABLE public.user_push_subscriptions
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_push_subscriptions
  ADD CONSTRAINT user_push_subscriptions_pkey PRIMARY KEY (id);

ALTER TABLE public.user_push_subscriptions
  ADD CONSTRAINT user_push_subscriptions_platform_check CHECK (platform = ANY (ARRAY['web'::text, 'android'::text]));

ALTER TABLE public.user_push_subscriptions
  ADD CONSTRAINT user_push_subscriptions_unique_token UNIQUE (user_id, fcm_token);

ALTER TABLE public.user_push_subscriptions
  ADD CONSTRAINT user_push_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

GRANT ALL ON public.user_push_subscriptions TO anon;

GRANT ALL ON public.user_push_subscriptions TO authenticated;

GRANT ALL ON public.user_push_subscriptions TO service_role;