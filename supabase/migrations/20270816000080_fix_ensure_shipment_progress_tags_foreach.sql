-- FOREACH into text[] over a 2D array raises 42804:
-- "FOREACH loop variable must not be of an array type".
-- Seed rows with a VALUES loop instead.

create or replace function public.ensure_shipment_progress_tags(p_tenant_id bigint)
returns setof public.tags
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email constant text := 'system@brandwala.local';
  v_slug text;
  v_name text;
  v_sort integer;
  v_existing_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id required';
  end if;

  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  for v_slug, v_name, v_sort in
    select *
    from (
      values
        ('uk-warehouse'::text, 'UK Warehouse'::text, 1),
        ('on-flight', 'On flight', 2),
        ('airport', 'Airport', 3),
        ('customs-clearance', 'Customs clearance', 4),
        ('bd-warehouse', 'BD Warehouse', 5)
    ) as s(slug, name, sort_order)
  loop
    select t.id into v_existing_id
    from public.tags t
    where t.tenant_id = p_tenant_id
      and t.slug = v_slug
      and t.group_name = 'shipment_progress'
    limit 1;

    if v_existing_id is null then
      insert into public.tags (
        tenant_id, name, slug, color, type, group_name, sort_order, created_by_email
      )
      values (
        p_tenant_id,
        v_name,
        v_slug,
        '#64748b',
        'shipment_progress',
        'shipment_progress',
        v_sort,
        v_email
      );
    else
      update public.tags
      set
        name = v_name,
        type = 'shipment_progress',
        group_name = 'shipment_progress',
        sort_order = v_sort
      where id = v_existing_id;
    end if;
  end loop;

  return query
    select t.*
    from public.tags t
    where t.tenant_id = p_tenant_id
      and t.group_name = 'shipment_progress'
    order by t.sort_order nulls last, t.name;
end;
$$;

grant execute on function public.ensure_shipment_progress_tags(bigint) to authenticated;
