-- Notifications domain — RPCs, helpers, and first plugin trigger

CREATE OR REPLACE FUNCTION public.resolve_notification_recipient_user_ids(
  p_parent_tenant_id bigint,
  p_operating_tenant_id bigint,
  p_audience public.notification_audience,
  p_recipient_user_ids uuid[] DEFAULT NULL,
  p_module_key text DEFAULT NULL,
  p_action text DEFAULT 'view'
)
RETURNS uuid[]
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_ids uuid[];
BEGIN
  IF p_audience = 'assignee_only' THEN
    IF p_recipient_user_ids IS NULL OR cardinality(p_recipient_user_ids) = 0 THEN
      RETURN ARRAY[]::uuid[];
    END IF;

    SELECT coalesce(array_agg(DISTINCT u.user_id), ARRAY[]::uuid[])
    INTO v_user_ids
    FROM unnest(p_recipient_user_ids) AS input(user_id)
    JOIN auth.users u ON u.id = input.user_id
    WHERE input.user_id IS NOT NULL;

    RETURN coalesce(v_user_ids, ARRAY[]::uuid[]);
  END IF;

  IF p_audience = 'child_only' AND p_operating_tenant_id IS NULL THEN
    RETURN ARRAY[]::uuid[];
  END IF;

  WITH pools AS (
    SELECT DISTINCT
      u.id AS user_id,
      m.tenant_id AS membership_tenant_id
    FROM public.memberships m
    JOIN auth.users u ON lower(trim(u.email)) = lower(trim(m.email))
    WHERE m.is_active = true
      AND (
        (
          p_audience IN ('child_only', 'child_and_parent')
          AND p_operating_tenant_id IS NOT NULL
          AND m.tenant_id = p_operating_tenant_id
        )
        OR (
          p_audience IN ('parent_only', 'child_and_parent')
          AND m.tenant_id = p_parent_tenant_id
        )
      )
  )
  SELECT coalesce(array_agg(DISTINCT p.user_id), ARRAY[]::uuid[])
  INTO v_user_ids
  FROM pools p
  WHERE p_module_key IS NULL
     OR public.membership_has_module_action(p.membership_tenant_id, p_module_key, p_action);

  RETURN coalesce(v_user_ids, ARRAY[]::uuid[]);
END;
$$;

ALTER FUNCTION public.resolve_notification_recipient_user_ids(
  bigint,
  bigint,
  public.notification_audience,
  uuid[],
  text,
  text
) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.resolve_notification_recipient_user_ids(
  bigint,
  bigint,
  public.notification_audience,
  uuid[],
  text,
  text
) FROM PUBLIC;


CREATE OR REPLACE FUNCTION public.enqueue_notification(
  p_tenant_id bigint,
  p_operating_tenant_id bigint,
  p_audience public.notification_audience,
  p_event_type text,
  p_title text,
  p_body text DEFAULT NULL,
  p_link_path text DEFAULT NULL,
  p_entity_type text DEFAULT NULL,
  p_entity_id text DEFAULT NULL,
  p_recipient_user_ids uuid[] DEFAULT NULL,
  p_module_key text DEFAULT NULL,
  p_action text DEFAULT 'view'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
$$;

ALTER FUNCTION public.enqueue_notification(
  bigint,
  bigint,
  public.notification_audience,
  text,
  text,
  text,
  text,
  text,
  text,
  uuid[],
  text,
  text
) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.enqueue_notification(
  bigint,
  bigint,
  public.notification_audience,
  text,
  text,
  text,
  text,
  text,
  text,
  uuid[],
  text,
  text
) FROM PUBLIC;


CREATE OR REPLACE FUNCTION public.notification_inbox_scope_matches(
  p_tenant_id bigint,
  p_parent_tenant_id bigint,
  p_operating_tenant_id bigint
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    p_parent_tenant_id = public.resolve_parent_tenant_id(p_tenant_id)
    AND (
      NOT EXISTS (
        SELECT 1
        FROM public.tenants t
        WHERE t.id = p_tenant_id
          AND t.parent_id IS NOT NULL
      )
      OR p_operating_tenant_id IS NULL
      OR p_operating_tenant_id = p_tenant_id
    );
$$;

ALTER FUNCTION public.notification_inbox_scope_matches(bigint, bigint, bigint) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.notification_inbox_scope_matches(bigint, bigint, bigint) FROM PUBLIC;


CREATE OR REPLACE FUNCTION public.list_my_notifications_paginated(
  p_tenant_id bigint,
  p_page integer DEFAULT 1,
  p_page_size integer DEFAULT 20,
  p_unread_only boolean DEFAULT false,
  p_event_type text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_total_count bigint;
  v_unread_count bigint;
  v_total_pages integer;
  v_data jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'p_tenant_id is required';
  END IF;

  IF NOT (
    public.is_superadmin()
    OR public.has_active_tenant_membership(p_tenant_id)
    OR public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(p_tenant_id))
  ) THEN
    RAISE EXCEPTION 'Permission denied for tenant %', p_tenant_id;
  END IF;

  SELECT count(*)
  INTO v_total_count
  FROM public.notification_recipients r
  JOIN public.notifications n ON n.id = r.notification_id
  WHERE r.user_id = v_user_id
    AND public.notification_inbox_scope_matches(p_tenant_id, n.parent_tenant_id, n.operating_tenant_id)
    AND (NOT p_unread_only OR r.read_at IS NULL)
    AND (p_event_type IS NULL OR p_event_type = '' OR n.event_type = p_event_type);

  SELECT count(*)
  INTO v_unread_count
  FROM public.notification_recipients r
  JOIN public.notifications n ON n.id = r.notification_id
  WHERE r.user_id = v_user_id
    AND r.read_at IS NULL
    AND public.notification_inbox_scope_matches(p_tenant_id, n.parent_tenant_id, n.operating_tenant_id);

  SELECT coalesce(jsonb_agg(row_to_json(x)::jsonb), '[]'::jsonb)
  INTO v_data
  FROM (
    SELECT
      r.id AS recipient_id,
      n.id AS notification_id,
      r.read_at,
      (r.read_at IS NULL) AS is_unread,
      n.event_type,
      n.title,
      n.body,
      n.link_path,
      n.entity_type,
      n.entity_id,
      n.parent_tenant_id,
      n.operating_tenant_id,
      n.created_at
    FROM public.notification_recipients r
    JOIN public.notifications n ON n.id = r.notification_id
    WHERE r.user_id = v_user_id
      AND public.notification_inbox_scope_matches(p_tenant_id, n.parent_tenant_id, n.operating_tenant_id)
      AND (NOT p_unread_only OR r.read_at IS NULL)
      AND (p_event_type IS NULL OR p_event_type = '' OR n.event_type = p_event_type)
    ORDER BY n.created_at DESC, r.created_at DESC
    LIMIT v_page_size
    OFFSET (v_page - 1) * v_page_size
  ) x;

  IF v_total_count = 0 THEN
    v_total_pages := 0;
  ELSE
    v_total_pages := ceil(v_total_count::numeric / v_page_size)::integer;
  END IF;

  RETURN jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total_count', v_total_count,
      'page', v_page,
      'page_size', v_page_size,
      'total_pages', v_total_pages,
      'unread_count', v_unread_count
    )
  );
END;
$$;

ALTER FUNCTION public.list_my_notifications_paginated(bigint, integer, integer, boolean, text) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.list_my_notifications_paginated(bigint, integer, integer, boolean, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_my_notifications_paginated(bigint, integer, integer, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_my_notifications_paginated(bigint, integer, integer, boolean, text) TO service_role;


CREATE OR REPLACE FUNCTION public.get_my_notification_unread_count(
  p_tenant_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_unread_count bigint;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'p_tenant_id is required';
  END IF;

  IF NOT (
    public.is_superadmin()
    OR public.has_active_tenant_membership(p_tenant_id)
    OR public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(p_tenant_id))
  ) THEN
    RAISE EXCEPTION 'Permission denied for tenant %', p_tenant_id;
  END IF;

  SELECT count(*)
  INTO v_unread_count
  FROM public.notification_recipients r
  JOIN public.notifications n ON n.id = r.notification_id
  WHERE r.user_id = v_user_id
    AND r.read_at IS NULL
    AND public.notification_inbox_scope_matches(p_tenant_id, n.parent_tenant_id, n.operating_tenant_id);

  RETURN jsonb_build_object('unread_count', coalesce(v_unread_count, 0));
END;
$$;

ALTER FUNCTION public.get_my_notification_unread_count(bigint) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.get_my_notification_unread_count(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_notification_unread_count(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_notification_unread_count(bigint) TO service_role;


CREATE OR REPLACE FUNCTION public.mark_notification_read(
  p_notification_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
$$;

ALTER FUNCTION public.mark_notification_read(uuid) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.mark_notification_read(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(uuid) TO service_role;


CREATE OR REPLACE FUNCTION public.mark_all_my_notifications_read(
  p_tenant_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_updated_count bigint;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'p_tenant_id is required';
  END IF;

  IF NOT (
    public.is_superadmin()
    OR public.has_active_tenant_membership(p_tenant_id)
    OR public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(p_tenant_id))
  ) THEN
    RAISE EXCEPTION 'Permission denied for tenant %', p_tenant_id;
  END IF;

  WITH updated AS (
    UPDATE public.notification_recipients r
    SET read_at = now()
    FROM public.notifications n
    WHERE n.id = r.notification_id
      AND r.user_id = v_user_id
      AND r.read_at IS NULL
      AND public.notification_inbox_scope_matches(p_tenant_id, n.parent_tenant_id, n.operating_tenant_id)
    RETURNING r.id
  )
  SELECT count(*) INTO v_updated_count FROM updated;

  RETURN jsonb_build_object(
    'success', true,
    'updated_count', coalesce(v_updated_count, 0)
  );
END;
$$;

ALTER FUNCTION public.mark_all_my_notifications_read(bigint) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.mark_all_my_notifications_read(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_all_my_notifications_read(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_all_my_notifications_read(bigint) TO service_role;


CREATE OR REPLACE FUNCTION public.trg_item_assignees_notify_assigned()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item public.items;
  v_assignee_user_id uuid;
  v_tenant_id bigint;
BEGIN
  SELECT i.*
  INTO v_item
  FROM public.items i
  WHERE i.id = NEW.item_id;

  IF NOT FOUND OR v_item.type IS DISTINCT FROM 'task' THEN
    RETURN NEW;
  END IF;

  v_tenant_id := v_item.tenant_id;
  IF v_tenant_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT u.id
  INTO v_assignee_user_id
  FROM auth.users u
  WHERE lower(trim(u.email)) = lower(trim(NEW.user_email))
  LIMIT 1;

  IF v_assignee_user_id IS NULL THEN
    RETURN NEW;
  END IF;

  PERFORM public.enqueue_notification(
    p_tenant_id := v_tenant_id,
    p_operating_tenant_id := v_tenant_id,
    p_audience := 'assignee_only',
    p_event_type := 'task.assigned',
    p_title := format('Task assigned: %s', v_item.title),
    p_body := nullif(trim(coalesce(v_item.content, '')), ''),
    p_link_path := '/app/tasks',
    p_entity_type := 'item',
    p_entity_id := v_item.id::text,
    p_recipient_user_ids := ARRAY[v_assignee_user_id],
    p_module_key := 'tasks',
    p_action := 'view'
  );

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.trg_item_assignees_notify_assigned() OWNER TO postgres;

DROP TRIGGER IF EXISTS trg_item_assignees_notify_assigned ON public.item_assignees;

CREATE TRIGGER trg_item_assignees_notify_assigned
  AFTER INSERT ON public.item_assignees
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_item_assignees_notify_assigned();


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

ALTER FUNCTION public.get_my_notification_preferences() OWNER TO postgres;

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

ALTER FUNCTION public.upsert_my_notification_preferences(boolean) OWNER TO postgres;

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

ALTER FUNCTION public.save_my_push_subscription(text, text) OWNER TO postgres;

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

ALTER FUNCTION public.delete_my_push_subscription(text) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.delete_my_push_subscription(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_my_push_subscription(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_my_push_subscription(text) TO service_role;


CREATE OR REPLACE FUNCTION public.set_notification_dispatch_settings(
  p_functions_url text,
  p_service_role_key text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notification_dispatch_settings (id, functions_url, service_role_key)
  VALUES (
    1,
    coalesce(nullif(trim(p_functions_url), ''), 'http://kong:8000'),
    nullif(trim(p_service_role_key), '')
  )
  ON CONFLICT (id) DO UPDATE SET
    functions_url = EXCLUDED.functions_url,
    service_role_key = EXCLUDED.service_role_key;
END;
$$;

ALTER FUNCTION public.set_notification_dispatch_settings(text, text) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.set_notification_dispatch_settings(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_notification_dispatch_settings(text, text) TO postgres;


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
  SELECT s.functions_url, s.service_role_key
  INTO v_functions_url, v_service_role_key
  FROM public.notification_dispatch_settings s
  WHERE s.id = 1;

  v_functions_url := coalesce(nullif(trim(v_functions_url), ''), 'http://kong:8000');
  v_service_role_key := nullif(trim(v_service_role_key), '');

  IF v_service_role_key IS NULL THEN
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

ALTER FUNCTION public.trg_notification_recipients_dispatch() OWNER TO postgres;

DROP TRIGGER IF EXISTS trg_notification_recipients_dispatch ON public.notification_recipients;

CREATE TRIGGER trg_notification_recipients_dispatch
  AFTER INSERT ON public.notification_recipients
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notification_recipients_dispatch();
