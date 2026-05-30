-- migration to return paginated jsonb with data and meta fields for costing files actor list

drop function if exists public.list_costing_files_for_actor(bigint, bigint, integer, integer);

create or replace function public.list_costing_files_for_actor(
  p_tenant_id bigint default null,
  p_customer_group_id bigint default null,
  p_page integer default 1,
  p_page_size integer default 20
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  -- Get total count of matching files
  select count(*)
  into v_total_count
  from public.costing_files cf
  where (p_tenant_id is null or cf.tenant_id = p_tenant_id)
    and (p_customer_group_id is null or cf.customer_group_id = p_customer_group_id)
    and public.can_view_costing_file(cf.id);

  -- Get paginated records as a jsonb array
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      cf.id,
      cf.name,
      cf.market,
      cf.status,
      cf.customer_group_id,
      cf.tenant_id,
      cf.created_by_email,
      public.resolve_costing_file_creator_label(
        cf.tenant_id,
        cf.customer_group_id,
        cf.created_by_email
      ) as created_by_label,
      cf.created_at,
      cf.updated_at
    from public.costing_files cf
    where (p_tenant_id is null or cf.tenant_id = p_tenant_id)
      and (p_customer_group_id is null or cf.customer_group_id = p_customer_group_id)
      and public.can_view_costing_file(cf.id)
    order by cf.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) r;

  -- Calculate total pages
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

grant execute on function public.list_costing_files_for_actor(bigint, bigint, integer, integer) to authenticated;
