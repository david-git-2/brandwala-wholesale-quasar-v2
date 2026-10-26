-- Firebase push: preferences, subscriptions, delivery log, client RPCs, dispatch trigger.

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE TABLE IF NOT EXISTS public.user_notification_preferences (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  channel_telegram boolean NOT NULL DEFAULT false,
  channel_push boolean NOT NULL DEFAULT false,
  channel_email boolean NOT NULL DEFAULT false,
  event_preferences jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_push_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token text NOT NULL,
  platform text NOT NULL DEFAULT 'web',
  created_at timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz,
  CONSTRAINT user_push_subscriptions_unique_token UNIQUE (user_id, fcm_token),
  CONSTRAINT user_push_subscriptions_platform_check CHECK (platform IN ('web', 'android'))
);

CREATE INDEX IF NOT EXISTS user_push_subscriptions_user_id_idx
  ON public.user_push_subscriptions (user_id);

CREATE TABLE IF NOT EXISTS public.notification_delivery_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id uuid NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  channel text NOT NULL,
  status text NOT NULL,
  error_message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT notification_delivery_log_channel_check CHECK (channel IN ('telegram', 'push', 'email')),
  CONSTRAINT notification_delivery_log_status_check CHECK (status IN ('sent', 'failed'))
);

CREATE INDEX IF NOT EXISTS notification_delivery_log_user_created_idx
  ON public.notification_delivery_log (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS notification_delivery_log_notification_id_idx
  ON public.notification_delivery_log (notification_id);

ALTER TABLE public.user_notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_push_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_delivery_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_notification_preferences_select_own ON public.user_notification_preferences;
DROP POLICY IF EXISTS user_notification_preferences_insert_own ON public.user_notification_preferences;
DROP POLICY IF EXISTS user_notification_preferences_update_own ON public.user_notification_preferences;
DROP POLICY IF EXISTS user_notification_preferences_delete_own ON public.user_notification_preferences;

CREATE POLICY user_notification_preferences_select_own
  ON public.user_notification_preferences FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY user_notification_preferences_insert_own
  ON public.user_notification_preferences FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY user_notification_preferences_update_own
  ON public.user_notification_preferences FOR UPDATE TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY user_notification_preferences_delete_own
  ON public.user_notification_preferences FOR DELETE TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS user_push_subscriptions_select_own ON public.user_push_subscriptions;
DROP POLICY IF EXISTS user_push_subscriptions_insert_own ON public.user_push_subscriptions;
DROP POLICY IF EXISTS user_push_subscriptions_update_own ON public.user_push_subscriptions;
DROP POLICY IF EXISTS user_push_subscriptions_delete_own ON public.user_push_subscriptions;

CREATE POLICY user_push_subscriptions_select_own
  ON public.user_push_subscriptions FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY user_push_subscriptions_insert_own
  ON public.user_push_subscriptions FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY user_push_subscriptions_update_own
  ON public.user_push_subscriptions FOR UPDATE TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY user_push_subscriptions_delete_own
  ON public.user_push_subscriptions FOR DELETE TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS notification_delivery_log_select_own ON public.notification_delivery_log;

CREATE POLICY notification_delivery_log_select_own
  ON public.notification_delivery_log FOR SELECT TO authenticated
  USING (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_notification_preferences TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_push_subscriptions TO authenticated;
GRANT SELECT ON public.notification_delivery_log TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_notification_preferences()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_row public.user_notification_preferences;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT p.*
  INTO v_row
  FROM public.user_notification_preferences p
  WHERE p.user_id = v_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'user_id', v_user_id,
      'channel_telegram', false,
      'channel_push', false,
      'channel_email', false,
      'event_preferences', '{}'::jsonb,
      'updated_at', NULL
    );
  END IF;

  RETURN jsonb_build_object(
    'user_id', v_row.user_id,
    'channel_telegram', v_row.channel_telegram,
    'channel_push', v_row.channel_push,
    'channel_email', v_row.channel_email,
    'event_preferences', v_row.event_preferences,
    'updated_at', v_row.updated_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_notification_preferences() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_notification_preferences() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_notification_preferences() TO service_role;

CREATE OR REPLACE FUNCTION public.upsert_my_notification_preferences(
  p_channel_push boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_row public.user_notification_preferences;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  INSERT INTO public.user_notification_preferences AS p (
    user_id,
    channel_push,
    updated_at
  )
  VALUES (
    v_user_id,
    coalesce(p_channel_push, false),
    now()
  )
  ON CONFLICT (user_id) DO UPDATE
  SET
    channel_push = EXCLUDED.channel_push,
    updated_at = now()
  RETURNING p.* INTO v_row;

  RETURN jsonb_build_object(
    'success', true,
    'channel_push', v_row.channel_push,
    'updated_at', v_row.updated_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.upsert_my_notification_preferences(boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.upsert_my_notification_preferences(boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_my_notification_preferences(boolean) TO service_role;

CREATE OR REPLACE FUNCTION public.save_my_push_subscription(
  p_fcm_token text,
  p_platform text DEFAULT 'web'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_token text := nullif(trim(coalesce(p_fcm_token, '')), '');
  v_platform text := coalesce(nullif(trim(coalesce(p_platform, '')), ''), 'web');
  v_subscription_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF v_token IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'p_fcm_token is required');
  END IF;

  IF v_platform NOT IN ('web', 'android') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid platform');
  END IF;

  INSERT INTO public.user_push_subscriptions AS s (
    user_id,
    fcm_token,
    platform,
    last_used_at
  )
  VALUES (
    v_user_id,
    v_token,
    v_platform,
    now()
  )
  ON CONFLICT (user_id, fcm_token) DO UPDATE
  SET
    platform = EXCLUDED.platform,
    last_used_at = now()
  RETURNING s.id INTO v_subscription_id;

  INSERT INTO public.user_notification_preferences AS p (
    user_id,
    channel_push,
    updated_at
  )
  VALUES (
    v_user_id,
    true,
    now()
  )
  ON CONFLICT (user_id) DO UPDATE
  SET
    channel_push = true,
    updated_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'subscription_id', v_subscription_id,
    'channel_push', true
  );
END;
$$;

REVOKE ALL ON FUNCTION public.save_my_push_subscription(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.save_my_push_subscription(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_my_push_subscription(text, text) TO service_role;

CREATE OR REPLACE FUNCTION public.delete_my_push_subscription(
  p_fcm_token text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_token text := nullif(trim(coalesce(p_fcm_token, '')), '');
  v_remaining bigint;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF v_token IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'p_fcm_token is required');
  END IF;

  DELETE FROM public.user_push_subscriptions s
  WHERE s.user_id = v_user_id
    AND s.fcm_token = v_token;

  SELECT count(*)
  INTO v_remaining
  FROM public.user_push_subscriptions s
  WHERE s.user_id = v_user_id;

  IF v_remaining = 0 THEN
    UPDATE public.user_notification_preferences p
    SET channel_push = false, updated_at = now()
    WHERE p.user_id = v_user_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'remaining_subscriptions', coalesce(v_remaining, 0),
    'channel_push', v_remaining > 0
  );
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_push_subscription(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_my_push_subscription(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_my_push_subscription(text) TO service_role;

CREATE OR REPLACE FUNCTION public.trg_notification_recipients_dispatch()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net
AS $$
DECLARE
  v_functions_url text;
  v_service_role_key text;
  v_url text;
BEGIN
  v_functions_url := nullif(trim(coalesce(current_setting('app.settings.supabase_functions_url', true), '')), '');
  v_service_role_key := nullif(trim(coalesce(current_setting('app.settings.service_role_key', true), '')), '');

  IF v_functions_url IS NULL OR v_service_role_key IS NULL THEN
    RETURN NEW;
  END IF;

  v_url := rtrim(v_functions_url, '/') || '/functions/v1/dispatch-notification';

  BEGIN
    PERFORM net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_service_role_key
      ),
      body := jsonb_build_object(
        'notification_id', NEW.notification_id,
        'user_id', NEW.user_id
      )
    );
  EXCEPTION
    WHEN OTHERS THEN
      RAISE LOG 'dispatch-notification enqueue failed: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notification_recipients_dispatch ON public.notification_recipients;

CREATE TRIGGER trg_notification_recipients_dispatch
  AFTER INSERT ON public.notification_recipients
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notification_recipients_dispatch();
