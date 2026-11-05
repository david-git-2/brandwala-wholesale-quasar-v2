CREATE FUNCTION public.mark_notification_read (
  p_notification_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_read_at timestamptz;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_notification_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'p_notification_id is required');
  END IF;

  UPDATE public.notification_recipients
  SET read_at = now()
  WHERE notification_id = p_notification_id
    AND user_id = v_user_id
    AND read_at IS NULL
  RETURNING read_at INTO v_read_at;

  IF v_read_at IS NULL THEN
    SELECT r.read_at
    INTO v_read_at
    FROM public.notification_recipients r
    WHERE r.notification_id = p_notification_id
      AND r.user_id = v_user_id;
  END IF;

  IF v_read_at IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Notification not found');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'notification_id', p_notification_id,
    'read_at', v_read_at
  );
END;
$function$;

GRANT ALL ON FUNCTION public.mark_notification_read(uuid) TO anon;

GRANT ALL ON FUNCTION public.mark_notification_read(uuid) TO authenticated;

GRANT ALL ON FUNCTION public.mark_notification_read(uuid) TO service_role;