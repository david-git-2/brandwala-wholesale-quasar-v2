-- Add public.get_item_details to reduce batch API calls when viewing details
drop function if exists public.get_item_details(bigint);

create or replace function public.get_item_details(
  p_item_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_email text;
  v_item jsonb;
  v_assignees jsonb;
  v_tags jsonb;
  v_comments jsonb;
  v_permissions jsonb;
  v_activity_logs jsonb;
begin
  v_email := public.current_user_email();

  -- Check item exists and permissions allow reading it
  if public.get_effective_item_role(p_item_id, v_email) is null then
    return null;
  end if;

  -- 1. Fetch item details
  select row_to_json(i)
  into v_item
  from public.items i
  where i.id = p_item_id;

  -- 2. Fetch assignees
  select coalesce(json_agg(row_to_json(ia)), '[]'::json)
  into v_assignees
  from (
    select * from public.item_assignees
    where item_id = p_item_id
  ) ia;

  -- 3. Fetch tags
  select coalesce(json_agg(row_to_json(t)), '[]'::json)
  into v_tags
  from (
    select t.* from public.item_tags it
    join public.tags t on t.id = it.tag_id
    where it.item_id = p_item_id
  ) t;

  -- 4. Fetch comments (ordered by created_at asc)
  select coalesce(json_agg(row_to_json(c)), '[]'::json)
  into v_comments
  from (
    select * from public.comments
    where item_id = p_item_id
    order by created_at asc
  ) c;

  -- 5. Fetch permissions
  select coalesce(json_agg(row_to_json(ip)), '[]'::json)
  into v_permissions
  from (
    select * from public.item_permissions
    where item_id = p_item_id
  ) ip;

  -- 6. Fetch activity logs (ordered by created_at desc)
  select coalesce(json_agg(row_to_json(al)), '[]'::json)
  into v_activity_logs
  from (
    select * from public.activity_logs
    where item_id = p_item_id
    order by created_at desc
  ) al;

  -- Return combined result
  return jsonb_build_object(
    'item', v_item,
    'assignees', v_assignees,
    'tags', v_tags,
    'comments', v_comments,
    'permissions', v_permissions,
    'activity_logs', v_activity_logs
  );
end;
$$;

grant execute on function public.get_item_details(bigint) to authenticated;
