CREATE FUNCTION public.get_my_notification_preferences()
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.get_my_notification_preferences() TO anon;

GRANT ALL ON FUNCTION public.get_my_notification_preferences() TO authenticated;

GRANT ALL ON FUNCTION public.get_my_notification_preferences() TO service_role;