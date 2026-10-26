-- Migration to add paginated jsonb items search and filtering function
drop function if exists public.list_items_paginated(bigint, integer, integer, text, text, text, text, text, text);

create or replace function public.list_items_paginated(
  p_tenant_id bigint default null,
  p_page integer default 1,
  p_page_size integer default 20,
  p_search text default null,
  p_type text default null,
  p_status text default null,
  p_priority text default null,
  p_assignee text default null,
  p_my_tasks_email text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_email text;
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  v_email := public.current_user_email();

  -- 1. Get total count of matching items
  select count(*)
  into v_total_count
  from public.items i
  where
    -- RLS / permissions check
    public.get_effective_item_role(i.id, v_email) is not null
    
    -- Tenant scoping
    and (
      (p_tenant_id is null and i.tenant_id is null)
      or (p_tenant_id is not null and i.tenant_id = p_tenant_id)
    )
    
    -- Search query filter
    and (
      p_search is null or p_search = '' or (
        i.title ilike '%' || p_search || '%'
        or i.content ilike '%' || p_search || '%'
      )
    )
    
    -- Type filter
    and (p_type is null or p_type = '' or i.type = p_type)
    
    -- Status filter
    and (p_status is null or p_status = '' or i.status = p_status)
    
    -- Priority filter
    and (p_priority is null or p_priority = '' or i.priority = p_priority)
    
    -- Assignee filter
    and (
      p_assignee is null or p_assignee = '' or exists (
        select 1 from public.item_assignees ia
        where ia.item_id = i.id and ia.user_email = p_assignee
      )
    )
    
    -- My tasks filter (assigned or created)
    and (
      p_my_tasks_email is null or p_my_tasks_email = '' or (
        i.created_by_email = p_my_tasks_email
        or exists (
          select 1 from public.item_assignees ia2
          where ia2.item_id = i.id and ia2.user_email = p_my_tasks_email
        )
      )
    );

  -- 2. Get paginated records as a jsonb array
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      i.id,
      i.tenant_id,
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
      i.updated_at,
      i.archived_at,
      (
        select coalesce(json_agg(json_build_object(
          'id', ia.id,
          'item_id', ia.item_id,
          'user_email', ia.user_email,
          'assigned_by_email', ia.assigned_by_email,
          'created_at', ia.created_at
        )), '[]'::json)
        from public.item_assignees ia
        where ia.item_id = i.id
      ) as assignees,
      (
        select coalesce(json_agg(json_build_object(
          'id', t.id,
          'tenant_id', t.tenant_id,
          'name', t.name,
          'slug', t.slug,
          'color', t.color,
          'type', t.type,
          'created_by_email', t.created_by_email,
          'created_at', t.created_at
        )), '[]'::json)
        from public.item_tags it
        join public.tags t on t.id = it.tag_id
        where it.item_id = i.id
      ) as tags
    from public.items i
    where
      -- RLS / permissions check
      public.get_effective_item_role(i.id, v_email) is not null
      
      -- Tenant scoping
      and (
        (p_tenant_id is null and i.tenant_id is null)
        or (p_tenant_id is not null and i.tenant_id = p_tenant_id)
      )
      
      -- Search query filter
      and (
        p_search is null or p_search = '' or (
          i.title ilike '%' || p_search || '%'
          or i.content ilike '%' || p_search || '%'
        )
      )
      
      -- Type filter
      and (p_type is null or p_type = '' or i.type = p_type)
      
      -- Status filter
      and (p_status is null or p_status = '' or i.status = p_status)
      
      -- Priority filter
      and (p_priority is null or p_priority = '' or i.priority = p_priority)
      
      -- Assignee filter
      and (
        p_assignee is null or p_assignee = '' or exists (
          select 1 from public.item_assignees ia
          where ia.item_id = i.id and ia.user_email = p_assignee
        )
      )
      
      -- My tasks filter (assigned or created)
      and (
        p_my_tasks_email is null or p_my_tasks_email = '' or (
          i.created_by_email = p_my_tasks_email
          or exists (
            select 1 from public.item_assignees ia2
            where ia2.item_id = i.id and ia2.user_email = p_my_tasks_email
          )
        )
      )
    order by i.created_at asc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) r;

  -- 3. Calculate total pages
  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::float / p_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total_count', v_total_count,
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', p_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$$;

grant execute on function public.list_items_paginated(bigint, integer, integer, text, text, text, text, text, text) to authenticated;
