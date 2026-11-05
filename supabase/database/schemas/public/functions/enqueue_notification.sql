CREATE FUNCTION public.enqueue_notification (
  p_tenant_id           bigint,
  p_operating_tenant_id bigint,
  p_audience            public.notification_audience,
  p_event_type          text,
  p_title               text,
  p_body                text                         DEFAULT NULL::text,
  p_link_path           text                         DEFAULT NULL::text,
  p_entity_type         text                         DEFAULT NULL::text,
  p_entity_id           text                         DEFAULT NULL::text,
  p_recipient_user_ids  uuid[]                       DEFAULT NULL::uuid[],
  p_module_key          text                         DEFAULT NULL::text,
  p_action              text                         DEFAULT 'view'::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_parent_tenant_id bigint;
  v_notification_id uuid;
  v_recipient_user_ids uuid[];
  v_title text := trim(coalesce(p_title, ''));
  v_event_type text := trim(coalesce(p_event_type, ''));
BEGIN
  IF p_tenant_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'p_tenant_id is required');
  END IF;

  IF v_title = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'p_title is required');
  END IF;

  IF v_event_type = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'p_event_type is required');
  END IF;

  IF p_audience = 'assignee_only'
     AND (p_recipient_user_ids IS NULL OR cardinality(p_recipient_user_ids) = 0) THEN
    RETURN jsonb_build_object('success', false, 'error', 'assignee_only requires p_recipient_user_ids');
  END IF;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  v_recipient_user_ids := public.resolve_notification_recipient_user_ids(
    v_parent_tenant_id,
    p_operating_tenant_id,
    p_audience,
    p_recipient_user_ids,
    p_module_key,
    p_action
  );

  IF v_recipient_user_ids IS NULL OR cardinality(v_recipient_user_ids) = 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'notification_id', NULL,
      'parent_tenant_id', v_parent_tenant_id,
      'operating_tenant_id', p_operating_tenant_id,
      'recipient_count', 0,
      'recipient_user_ids', '[]'::jsonb
    );
  END IF;

  INSERT INTO public.notifications (
    parent_tenant_id,
    operating_tenant_id,
    event_type,
    title,
    body,
    link_path,
    entity_type,
    entity_id
  )
  VALUES (
    v_parent_tenant_id,
    p_operating_tenant_id,
    v_event_type,
    v_title,
    nullif(trim(coalesce(p_body, '')), ''),
    nullif(trim(coalesce(p_link_path, '')), ''),
    nullif(trim(coalesce(p_entity_type, '')), ''),
    nullif(trim(coalesce(p_entity_id, '')), '')
  )
  RETURNING id INTO v_notification_id;

  INSERT INTO public.notification_recipients (notification_id, user_id)
  SELECT v_notification_id, recipient_user_id
  FROM unnest(v_recipient_user_ids) AS recipient_user_id
  ON CONFLICT (notification_id, user_id) DO NOTHING;

  RETURN jsonb_build_object(
    'success', true,
    'notification_id', v_notification_id,
    'parent_tenant_id', v_parent_tenant_id,
    'operating_tenant_id', p_operating_tenant_id,
    'recipient_count', cardinality(v_recipient_user_ids),
    'recipient_user_ids', to_jsonb(v_recipient_user_ids)
  );
END;
$function$;

GRANT ALL ON FUNCTION public.enqueue_notification(bigint, bigint, public.notification_audience, text, text, text, text, text, text, uuid[], text, text) TO anon;

GRANT ALL ON FUNCTION public.enqueue_notification(bigint, bigint, public.notification_audience, text, text, text, text, text, text, uuid[], text, text) TO authenticated;

GRANT ALL ON FUNCTION public.enqueue_notification(bigint, bigint, public.notification_audience, text, text, text, text, text, text, uuid[], text, text) TO service_role;