CREATE FUNCTION public.get_tasks_dashboard_metrics (
  p_tenant_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_email text;
  v_today date;
  v_assigned bigint := 0;
  v_overdue bigint := 0;
  v_due_today bigint := 0;
  v_unassigned bigint := 0;
  v_todo bigint := 0;
  v_doing bigint := 0;
  v_stuck bigint := 0;
  v_done bigint := 0;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'tasks', 'view') THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_email := public.current_user_email();
  v_today := (timezone('Asia/Dhaka', now()))::date;

  SELECT
    count(*) FILTER (
      WHERE EXISTS (
        SELECT 1 FROM public.item_assignees ia
        WHERE ia.item_id = i.id AND ia.user_email = v_email
      )
      AND i.status NOT IN ('done', 'archived')
    ),
    count(*) FILTER (
      WHERE i.due_date IS NOT NULL
        AND i.due_date < now()
        AND i.status NOT IN ('done', 'archived')
    ),
    count(*) FILTER (
      WHERE i.due_date IS NOT NULL
        AND (timezone('Asia/Dhaka', i.due_date))::date = v_today
        AND i.status NOT IN ('done', 'archived')
    ),
    count(*) FILTER (
      WHERE NOT EXISTS (SELECT 1 FROM public.item_assignees ia WHERE ia.item_id = i.id)
        AND i.status NOT IN ('done', 'archived')
    ),
    count(*) FILTER (
      WHERE EXISTS (
        SELECT 1 FROM public.item_assignees ia
        WHERE ia.item_id = i.id AND ia.user_email = v_email
      )
      AND i.status = 'todo'
    ),
    count(*) FILTER (
      WHERE EXISTS (
        SELECT 1 FROM public.item_assignees ia
        WHERE ia.item_id = i.id AND ia.user_email = v_email
      )
      AND i.status = 'in_progress'
    ),
    count(*) FILTER (
      WHERE EXISTS (
        SELECT 1 FROM public.item_assignees ia
        WHERE ia.item_id = i.id AND ia.user_email = v_email
      )
      AND i.status IN ('blocked', 'review')
    ),
    count(*) FILTER (
      WHERE EXISTS (
        SELECT 1 FROM public.item_assignees ia
        WHERE ia.item_id = i.id AND ia.user_email = v_email
      )
      AND i.status = 'done'
    )
  INTO v_assigned, v_overdue, v_due_today, v_unassigned, v_todo, v_doing, v_stuck, v_done
  FROM public.items i
  WHERE i.tenant_id = p_tenant_id
    AND i.type = 'task'
    AND i.archived_at IS NULL;

  RETURN jsonb_build_object(
    'tenant_id', p_tenant_id,
    'assigned_to_me', v_assigned,
    'overdue_count', v_overdue,
    'due_today_count', v_due_today,
    'unassigned_count', v_unassigned,
    'my_todo', v_todo,
    'my_doing', v_doing,
    'my_stuck', v_stuck,
    'my_done', v_done
  );
END;
$function$;

GRANT ALL ON FUNCTION public.get_tasks_dashboard_metrics(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_tasks_dashboard_metrics(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_tasks_dashboard_metrics(bigint) TO service_role;