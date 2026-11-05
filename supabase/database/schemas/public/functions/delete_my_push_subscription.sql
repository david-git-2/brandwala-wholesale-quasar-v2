CREATE FUNCTION public.delete_my_push_subscription (
  p_fcm_token text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.delete_my_push_subscription(text) TO anon;

GRANT ALL ON FUNCTION public.delete_my_push_subscription(text) TO authenticated;

GRANT ALL ON FUNCTION public.delete_my_push_subscription(text) TO service_role;