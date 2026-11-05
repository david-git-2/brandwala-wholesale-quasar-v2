CREATE FUNCTION public.upsert_my_notification_preferences (
  p_channel_push boolean
)
  RETURNS jsonb
  LANGUAGE plpgsql
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
$function$;

GRANT ALL ON FUNCTION public.upsert_my_notification_preferences(boolean) TO anon;

GRANT ALL ON FUNCTION public.upsert_my_notification_preferences(boolean) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_my_notification_preferences(boolean) TO service_role;