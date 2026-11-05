CREATE FUNCTION public.save_my_push_subscription (
  p_fcm_token text,
  p_platform  text DEFAULT 'web'::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.save_my_push_subscription(text, text) TO anon;

GRANT ALL ON FUNCTION public.save_my_push_subscription(text, text) TO authenticated;

GRANT ALL ON FUNCTION public.save_my_push_subscription(text, text) TO service_role;