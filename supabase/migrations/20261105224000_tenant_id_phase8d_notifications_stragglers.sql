-- Phase 8d: notifications + tenant_data_purge_logs column rename.
ALTER TABLE public.notifications RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.tenant_data_purge_logs RENAME COLUMN parent_tenant_id TO tenant_id;

DROP INDEX IF EXISTS public.notifications_parent_operating_created_idx;
DROP INDEX IF EXISTS public.notifications_parent_tenant_created_idx;
CREATE INDEX "notifications_parent_operating_created_idx" ON public.notifications USING btree (tenant_id, operating_tenant_id, created_at DESC);
CREATE INDEX "notifications_parent_tenant_created_idx" ON public.notifications USING btree (tenant_id, created_at DESC);

DROP POLICY IF EXISTS tenant_data_purge_logs_select ON public.tenant_data_purge_logs;
CREATE POLICY "tenant_data_purge_logs_select" ON public.tenant_data_purge_logs FOR SELECT TO authenticated USING ((public.is_superadmin() OR public.user_can_manage_parent_tenant(tenant_id)));

-- notification RPCs

CREATE OR REPLACE FUNCTION "public"."enqueue_notification"("p_tenant_id" bigint, "p_operating_tenant_id" bigint, "p_audience" "public"."notification_audience", "p_event_type" "text", "p_title" "text", "p_body" "text" DEFAULT NULL::"text", "p_link_path" "text" DEFAULT NULL::"text", "p_entity_type" "text" DEFAULT NULL::"text", "p_entity_id" "text" DEFAULT NULL::"text", "p_recipient_user_ids" "uuid"[] DEFAULT NULL::"uuid"[], "p_module_key" "text" DEFAULT NULL::"text", "p_action" "text" DEFAULT 'view'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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
    tenant_id,
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

CREATE OR REPLACE FUNCTION "public"."get_my_notification_unread_count"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_unread_count bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  if not (
    public.is_superadmin()
    or public.has_active_tenant_membership(p_tenant_id)
    or public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(p_tenant_id))
    or public.has_shop_notification_access(p_tenant_id)
  ) then
    raise exception 'Permission denied for tenant %', p_tenant_id;
  end if;

  select count(*)
  into v_unread_count
  from public.notification_recipients r
  join public.notifications n on n.id = r.notification_id
  where r.user_id = v_user_id
    and r.read_at is null
    and public.notification_inbox_scope_matches(p_tenant_id, n.tenant_id, n.operating_tenant_id);

  return jsonb_build_object('unread_count', coalesce(v_unread_count, 0));
end;
$$;

CREATE OR REPLACE FUNCTION "public"."list_my_notifications_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_unread_only" boolean DEFAULT false, "p_event_type" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_total_count bigint;
  v_unread_count bigint;
  v_total_pages integer;
  v_data jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  if not (
    public.is_superadmin()
    or public.has_active_tenant_membership(p_tenant_id)
    or public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(p_tenant_id))
    or public.has_shop_notification_access(p_tenant_id)
  ) then
    raise exception 'Permission denied for tenant %', p_tenant_id;
  end if;

  select count(*)
  into v_total_count
  from public.notification_recipients r
  join public.notifications n on n.id = r.notification_id
  where r.user_id = v_user_id
    and public.notification_inbox_scope_matches(p_tenant_id, n.tenant_id, n.operating_tenant_id)
    and (not p_unread_only or r.read_at is null)
    and (p_event_type is null or p_event_type = '' or n.event_type = p_event_type);

  select count(*)
  into v_unread_count
  from public.notification_recipients r
  join public.notifications n on n.id = r.notification_id
  where r.user_id = v_user_id
    and r.read_at is null
    and public.notification_inbox_scope_matches(p_tenant_id, n.tenant_id, n.operating_tenant_id);

  select coalesce(jsonb_agg(row_to_json(x)::jsonb), '[]'::jsonb)
  into v_data
  from (
    select
      r.id as recipient_id,
      n.id as notification_id,
      r.read_at,
      (r.read_at is null) as is_unread,
      n.event_type,
      n.title,
      n.body,
      n.link_path,
      n.entity_type,
      n.entity_id,
      n.tenant_id,
      n.operating_tenant_id,
      t.name as operating_tenant_name,
      n.created_at
    from public.notification_recipients r
    join public.notifications n on n.id = r.notification_id
    left join public.tenants t on t.id = n.operating_tenant_id
    where r.user_id = v_user_id
      and public.notification_inbox_scope_matches(p_tenant_id, n.tenant_id, n.operating_tenant_id)
      and (not p_unread_only or r.read_at is null)
      and (p_event_type is null or p_event_type = '' or n.event_type = p_event_type)
    order by n.created_at desc, r.created_at desc
    limit v_page_size
    offset (v_page - 1) * v_page_size
  ) x;

  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::numeric / v_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total_count', v_total_count,
      'page', v_page,
      'page_size', v_page_size,
      'total_pages', v_total_pages,
      'unread_count', v_unread_count
    )
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."mark_all_my_notifications_read"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_updated_count bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  if not (
    public.is_superadmin()
    or public.has_active_tenant_membership(p_tenant_id)
    or public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(p_tenant_id))
    or public.has_shop_notification_access(p_tenant_id)
  ) then
    raise exception 'Permission denied for tenant %', p_tenant_id;
  end if;

  with updated as (
    update public.notification_recipients r
    set read_at = now()
    from public.notifications n
    where n.id = r.notification_id
      and r.user_id = v_user_id
      and r.read_at is null
      and public.notification_inbox_scope_matches(p_tenant_id, n.tenant_id, n.operating_tenant_id)
    returning r.id
  )
  select count(*) into v_updated_count from updated;

  return jsonb_build_object(
    'success', true,
    'updated_count', coalesce(v_updated_count, 0)
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."mark_notification_read"("p_notification_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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
