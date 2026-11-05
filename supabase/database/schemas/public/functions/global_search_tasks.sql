CREATE FUNCTION public.global_search_tasks (
  p_query text
)
  RETURNS TABLE (
    id               bigint,
    tenant_id        bigint,
    tenant_name      text,
    parent_id        bigint,
    type             text,
    title            text,
    content          text,
    status           text,
    priority         text,
    created_by_email text,
    due_date         timestamp with time zone,
    start_date       timestamp with time zone,
    created_at       timestamp with time zone,
    updated_at       timestamp with time zone
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_email text;
begin
  v_email := public.current_user_email();

  return query
  select distinct
    i.id,
    i.tenant_id,
    t.name as tenant_name,
    i.parent_id,
    i.type,
    i.title,
    i.content,
    i.status,
    i.priority,
    i.created_by_email,
    i.due_date,
    i.start_date,
    i.created_at,
    i.updated_at
  from public.items i
  left join public.tenants t on t.id = i.tenant_id
  left join public.item_tags it on it.item_id = i.id
  left join public.tags tag on tag.id = it.tag_id
  left join public.comments c on c.item_id = i.id
  where
    public.get_effective_item_role(i.id, v_email) is not null
    and (
      i.title ilike '%' || p_query || '%'
      or i.content ilike '%' || p_query || '%'
      or tag.name ilike '%' || p_query || '%'
      or c.body ilike '%' || p_query || '%'
    )
  order by i.updated_at desc
  limit 50;
end;
$function$;

GRANT ALL ON FUNCTION public.global_search_tasks(text) TO anon;

GRANT ALL ON FUNCTION public.global_search_tasks(text) TO authenticated;

GRANT ALL ON FUNCTION public.global_search_tasks(text) TO service_role;