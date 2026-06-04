-- Migration: Exclude expired items from usable stock subtraction
begin;

create or replace function public.refresh_commerce_inventory_product_summary_single(
  p_tenant_id bigint,
  p_product_id bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_available integer := 0;
  v_reserved integer := 0;
  v_damaged integer := 0;
  v_stolen integer := 0;
  v_expired integer := 0;
  v_open_box integer := 0;
  v_usable integer := 0;
  v_exists boolean := false;
begin
  if p_tenant_id is null or p_product_id is null then
    return;
  end if;

  select
    count(*) > 0,
    coalesce(sum(coalesce(st.available_quantity, 0)), 0)::int,
    coalesce(sum(coalesce(st.reserved_quantity, 0)), 0)::int,
    coalesce(sum(coalesce(st.damaged_quantity, 0)), 0)::int,
    coalesce(sum(coalesce(st.stolen_quantity, 0)), 0)::int,
    coalesce(sum(coalesce(st.expired_quantity, 0)), 0)::int,
    coalesce(sum(coalesce(st.open_box_quantity, 0)), 0)::int,
    coalesce(
      sum(
        greatest(
          0,
          coalesce(st.available_quantity, 0)
          - coalesce(st.reserved_quantity, 0)
          - coalesce(st.damaged_quantity, 0)
          - coalesce(st.stolen_quantity, 0)
        )
      ),
      0
    )::int
  into
    v_exists,
    v_available,
    v_reserved,
    v_damaged,
    v_stolen,
    v_expired,
    v_open_box,
    v_usable
  from public.inventory_items ii
  left join public.inventory_stocks st
    on st.inventory_item_id = ii.id
  where ii.tenant_id = p_tenant_id
    and ii.product_id = p_product_id
    and ii.status = 'active';

  if not v_exists then
    delete from public.commerce_inventory_product_summaries
    where tenant_id = p_tenant_id
      and product_id = p_product_id;
    return;
  end if;

  insert into public.commerce_inventory_product_summaries (
    tenant_id,
    product_id,
    available_quantity,
    reserved_quantity,
    damaged_quantity,
    stolen_quantity,
    expired_quantity,
    open_box_quantity,
    usable_quantity,
    updated_at
  )
  values (
    p_tenant_id,
    p_product_id,
    v_available,
    v_reserved,
    v_damaged,
    v_stolen,
    v_expired,
    v_open_box,
    v_usable,
    now()
  )
  on conflict (tenant_id, product_id)
  do update set
    available_quantity = excluded.available_quantity,
    reserved_quantity = excluded.reserved_quantity,
    damaged_quantity = excluded.damaged_quantity,
    stolen_quantity = excluded.stolen_quantity,
    expired_quantity = excluded.expired_quantity,
    open_box_quantity = excluded.open_box_quantity,
    usable_quantity = excluded.usable_quantity,
    updated_at = now();
end;
$$;

-- Trigger recalculation of all product summaries to apply new logic
select public.refresh_commerce_inventory_product_summaries(null);

commit;
