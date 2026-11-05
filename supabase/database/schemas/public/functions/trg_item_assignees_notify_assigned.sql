CREATE FUNCTION public.trg_item_assignees_notify_assigned()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
    p_title := format('Task: %s', v_item.title),
    p_body := 'Open this task',
    p_link_path := '/app/tasks',
    p_entity_type := 'item',
    p_entity_id := v_item.id::text,
    p_recipient_user_ids := ARRAY[v_assignee_user_id],
    p_module_key := 'tasks',
    p_action := 'view'
  );

  RETURN NEW;
END;
$function$;

GRANT ALL ON FUNCTION public.trg_item_assignees_notify_assigned() TO anon;

GRANT ALL ON FUNCTION public.trg_item_assignees_notify_assigned() TO authenticated;

GRANT ALL ON FUNCTION public.trg_item_assignees_notify_assigned() TO service_role;