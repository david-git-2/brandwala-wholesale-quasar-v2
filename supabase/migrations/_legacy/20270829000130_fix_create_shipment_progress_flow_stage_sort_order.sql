-- Qualify sort_order / flow_id so they do not collide with RETURNS TABLE
-- OUT variables (SQLSTATE 42702: column reference "sort_order" is ambiguous).

begin;

create or replace function public.create_shipment_progress_flow_stage(
  p_flow_id bigint,
  p_name text,
  p_color text default '#64748b',
  p_sort_order integer default null
)
returns table (
  flow_stage_id bigint,
  flow_id bigint,
  tag_id bigint,
  sort_order integer,
  name text,
  slug text,
  color text,
  is_active boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_flow public.shipment_progress_flows;
  v_slug text;
  v_tag public.tags;
  v_sort integer;
begin
  select * into v_flow
  from public.shipment_progress_flows
  where id = p_flow_id;

  if not found then
    raise exception 'flow not found';
  end if;

  if not public.has_active_tenant_membership(v_flow.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_name is null or trim(p_name) = '' then
    raise exception 'name is required';
  end if;

  v_slug := lower(regexp_replace(trim(p_name), '[^a-z0-9]+', '-', 'gi'));

  if p_sort_order is null then
    select coalesce(max(s.sort_order), 0) + 1
    into v_sort
    from public.shipment_progress_flow_stages s
    where s.flow_id = p_flow_id;
  else
    v_sort := p_sort_order;
  end if;

  insert into public.tags (
    tenant_id, name, slug, color, type, group_name, sort_order, is_active, is_system, created_by_email
  )
  values (
    v_flow.tenant_id,
    trim(p_name),
    v_slug,
    coalesce(p_color, '#64748b'),
    'shipment_progress',
    'shipment_progress',
    v_sort,
    true,
    false,
    'tenant-settings'
  )
  returning * into v_tag;

  return query
  with inserted as (
    insert into public.shipment_progress_flow_stages as s(flow_id, tag_id, sort_order)
    values (p_flow_id, v_tag.id, v_sort)
    returning s.id, s.flow_id, s.tag_id, s.sort_order
  )
  select
    i.id,
    i.flow_id,
    i.tag_id,
    i.sort_order,
    v_tag.name,
    v_tag.slug,
    v_tag.color,
    v_tag.is_active
  from inserted i;
end;
$$;

grant execute on function public.create_shipment_progress_flow_stage(bigint, text, text, integer) to authenticated;

commit;
