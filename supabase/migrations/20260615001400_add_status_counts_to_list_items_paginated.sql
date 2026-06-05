-- Migration to add status counts to list_items_paginated metadata
begin;

-- 1. Drop existing function
drop function if exists public.list_items_paginated(bigint, integer, integer, text, text, text, text, text, text, boolean, bigint);

-- 2. Recreate list_items_paginated with status counts calculated
create or replace function public.list_items_paginated(
  p_tenant_id bigint default null,
  p_page integer default 1,
  p_page_size integer default 20,
  p_search text default null,
  p_type text default null,
  p_status text default null,
  p_priority text default null,
  p_assignee text default null,
  p_my_tasks_email text default null,
  p_include_parents boolean default false,
  p_tag_id bigint default null
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
  
  -- Status count variables
  v_todo_count bigint;
  v_in_progress_count bigint;
  v_review_count bigint;
  v_done_count bigint;
  v_blocked_count bigint;
  v_archived_count bigint;
begin
  v_email := public.current_user_email();

  -- Calculate status counts for all items matching the query filters (ignoring pagination limits)
  select
    count(*) filter (where i.status = 'todo'),
    count(*) filter (where i.status = 'in_progress'),
    count(*) filter (where i.status = 'review'),
    count(*) filter (where i.status = 'done'),
    count(*) filter (where i.status = 'blocked'),
    count(*) filter (where i.status = 'archived')
  into
    v_todo_count,
    v_in_progress_count,
    v_review_count,
    v_done_count,
    v_blocked_count,
    v_archived_count
  from public.items i
  where
    public.get_effective_item_role(i.id, v_email) is not null
    and (p_search is null or p_search = '' or (i.title ilike '%' || p_search || '%' or i.content ilike '%' || p_search || '%'))
    and (p_type is null or p_type = '' or i.type = p_type)
    and (p_status is null or p_status = '' or i.status = p_status)
    and (p_priority is null or p_priority = '' or i.priority = p_priority)
    and (p_assignee is null or p_assignee = '' or exists (select 1 from public.item_assignees ia where ia.item_id = i.id and ia.user_email = p_assignee))
    and (p_my_tasks_email is null or p_my_tasks_email = '' or (i.created_by_email = p_my_tasks_email or exists (select 1 from public.item_assignees ia2 where ia2.item_id = i.id and ia2.user_email = p_my_tasks_email)))
    and (p_tag_id is null or exists (select 1 from public.item_tags it where it.item_id = i.id and it.tag_id = p_tag_id));

  if p_include_parents then
    -- 1. Get total count of all unique items in matching items hierarchy
    select count(*)
    into v_total_count
    from (
      with recursive matching_items as (
        select i.id, i.parent_id
        from public.items i
        where
          public.get_effective_item_role(i.id, v_email) is not null
          and (p_search is null or p_search = '' or (i.title ilike '%' || p_search || '%' or i.content ilike '%' || p_search || '%'))
          and (p_type is null or p_type = '' or i.type = p_type)
          and (p_status is null or p_status = '' or i.status = p_status)
          and (p_priority is null or p_priority = '' or i.priority = p_priority)
          and (p_assignee is null or p_assignee = '' or exists (select 1 from public.item_assignees ia where ia.item_id = i.id and ia.user_email = p_assignee))
          and (p_my_tasks_email is null or p_my_tasks_email = '' or (i.created_by_email = p_my_tasks_email or exists (select 1 from public.item_assignees ia2 where ia2.item_id = i.id and ia2.user_email = p_my_tasks_email)))
          and (p_tag_id is null or exists (select 1 from public.item_tags it where it.item_id = i.id and it.tag_id = p_tag_id))
      ),
      item_hierarchy as (
        select m.id, m.parent_id
        from matching_items m
        
        union
        
        select p.id, p.parent_id
        from public.items p
        join item_hierarchy h on h.parent_id = p.id
        where public.get_effective_item_role(p.id, v_email) is not null
      )
      select distinct id from item_hierarchy
    ) distinct_hierarchy;

    -- 2. Get hierarchy records as a jsonb array
    select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
    into v_data
    from (
      with recursive matching_items as (
        select *
        from public.items i
        where
          public.get_effective_item_role(i.id, v_email) is not null
          and (p_search is null or p_search = '' or (i.title ilike '%' || p_search || '%' or i.content ilike '%' || p_search || '%'))
          and (p_type is null or p_type = '' or i.type = p_type)
          and (p_status is null or p_status = '' or i.status = p_status)
          and (p_priority is null or p_priority = '' or i.priority = p_priority)
          and (p_assignee is null or p_assignee = '' or exists (select 1 from public.item_assignees ia where ia.item_id = i.id and ia.user_email = p_assignee))
          and (p_my_tasks_email is null or p_my_tasks_email = '' or (i.created_by_email = p_my_tasks_email or exists (select 1 from public.item_assignees ia2 where ia2.item_id = i.id and ia2.user_email = p_my_tasks_email)))
          and (p_tag_id is null or exists (select 1 from public.item_tags it where it.item_id = i.id and it.tag_id = p_tag_id))
      ),
      item_hierarchy as (
        select
          m.id, m.tenant_id, m.parent_id, m.type, m.title, m.content, m.status, m.priority, m.is_markdown,
          m.created_by_email, m.due_date, m.start_date, m.created_at, m.updated_at, m.archived_at
        from matching_items m
        
        union
        
        select
          p.id, p.tenant_id, p.parent_id, p.type, p.title, p.content, p.status, p.priority, p.is_markdown,
          p.created_by_email, p.due_date, p.start_date, p.created_at, p.updated_at, p.archived_at
        from public.items p
        join item_hierarchy h on h.parent_id = p.id
        where public.get_effective_item_role(p.id, v_email) is not null
      ),
      distinct_hierarchy as (
        select distinct
          id, tenant_id, parent_id, type, title, content, status, priority, is_markdown,
          created_by_email, due_date, start_date, created_at, updated_at, archived_at
        from item_hierarchy
      )
      select
        dh.id, dh.tenant_id, dh.parent_id, dh.type, dh.title, dh.content, dh.status, dh.priority, dh.is_markdown,
        dh.created_by_email, dh.due_date, dh.start_date, dh.created_at, dh.updated_at, dh.archived_at,
        (
          select coalesce(json_agg(json_build_object(
            'id', ia.id,
            'item_id', ia.item_id,
            'user_email', ia.user_email,
            'assigned_by_email', ia.assigned_by_email,
            'created_at', ia.created_at
          )), '[]'::json)
          from public.item_assignees ia
          where ia.item_id = dh.id
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
          where it.item_id = dh.id
        ) as tags
      from distinct_hierarchy dh
      order by dh.created_at asc
      limit p_page_size
      offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
    ) r;

  else
    -- Flat list pagination
    -- 1. Get total count
    select count(*)
    into v_total_count
    from public.items i
    where
      public.get_effective_item_role(i.id, v_email) is not null
      and (p_search is null or p_search = '' or (i.title ilike '%' || p_search || '%' or i.content ilike '%' || p_search || '%'))
      and (p_type is null or p_type = '' or i.type = p_type)
      and (p_status is null or p_status = '' or i.status = p_status)
      and (p_priority is null or p_priority = '' or i.priority = p_priority)
      and (p_assignee is null or p_assignee = '' or exists (select 1 from public.item_assignees ia where ia.item_id = i.id and ia.user_email = p_assignee))
      and (p_my_tasks_email is null or p_my_tasks_email = '' or (i.created_by_email = p_my_tasks_email or exists (select 1 from public.item_assignees ia2 where ia2.item_id = i.id and ia2.user_email = p_my_tasks_email)))
      and (p_tag_id is null or exists (select 1 from public.item_tags it where it.item_id = i.id and it.tag_id = p_tag_id));

    -- 2. Get flat list items
    select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
    into v_data
    from (
      select
        i.id, i.tenant_id, i.parent_id, i.type, i.title, i.content, i.status, i.priority, i.is_markdown,
        i.created_by_email, i.due_date, i.start_date, i.created_at, i.updated_at, i.archived_at,
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
        public.get_effective_item_role(i.id, v_email) is not null
        and (p_search is null or p_search = '' or (i.title ilike '%' || p_search || '%' or i.content ilike '%' || p_search || '%'))
        and (p_type is null or p_type = '' or i.type = p_type)
        and (p_status is null or p_status = '' or i.status = p_status)
        and (p_priority is null or p_priority = '' or i.priority = p_priority)
        and (p_assignee is null or p_assignee = '' or exists (select 1 from public.item_assignees ia where ia.item_id = i.id and ia.user_email = p_assignee))
        and (p_my_tasks_email is null or p_my_tasks_email = '' or (i.created_by_email = p_my_tasks_email or exists (select 1 from public.item_assignees ia2 where ia2.item_id = i.id and ia2.user_email = p_my_tasks_email)))
        and (p_tag_id is null or exists (select 1 from public.item_tags it where it.item_id = i.id and it.tag_id = p_tag_id))
      order by i.created_at asc
      limit p_page_size
      offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
    ) r;
  end if;

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
      'total_pages', v_total_pages,
      'status_counts', jsonb_build_object(
        'todo', coalesce(v_todo_count, 0),
        'in_progress', coalesce(v_in_progress_count, 0),
        'review', coalesce(v_review_count, 0),
        'done', coalesce(v_done_count, 0),
        'blocked', coalesce(v_blocked_count, 0),
        'archived', coalesce(v_archived_count, 0)
      )
    )
  );
end;
$$;

grant execute on function public.list_items_paginated(bigint, integer, integer, text, text, text, text, text, text, boolean, bigint) to authenticated;

-- Reload schema cache
do $$
begin
  perform pg_notify('pgrst', 'reload schema');
exception
  when others then
    null;
end;
$$;

commit;
