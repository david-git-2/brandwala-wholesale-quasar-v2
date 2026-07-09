-- Migration: Create RPC list_shipment_items_for_shipments to batch fetch shipment costing details

create or replace function public.list_shipment_items_for_shipments(p_shipment_ids bigint[])
returns table (
  shipment_id bigint,
  purchase_price numeric,
  product_weight numeric,
  package_weight numeric,
  ordered_quantity integer
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if p_shipment_ids is null or array_length(p_shipment_ids, 1) is null or array_length(p_shipment_ids, 1) = 0 then
    return;
  end if;

  return query
  select
    gsi.shipment_id,
    gsi.purchase_price,
    gsi.product_weight,
    gsi.package_weight,
    gsi.ordered_quantity
  from public.global_shipment_items gsi
  inner join public.global_shipments gs on gs.id = gsi.shipment_id
  where gsi.shipment_id = any(p_shipment_ids)
    and (
      public.user_can_manage_parent_tenant(gs.parent_tenant_id)
      or exists (
        select 1 from public.memberships m
        where m.tenant_id = gs.parent_tenant_id
          and lower(trim(m.email)) = public.current_user_email()
          and m.is_active = true
      )
    )
  order by gsi.shipment_id, gsi.sort_order, gsi.id;
end;
$$;

grant execute on function public.list_shipment_items_for_shipments(bigint[]) to authenticated;
