create or replace function public.bulk_update_order_items(
  p_items jsonb
)
returns setof public.order_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item jsonb;
  v_id bigint;
  v_patch jsonb;
  v_updated public.order_items;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'p_items must be a JSON array';
  end if;

  for v_item in
    select value
    from jsonb_array_elements(p_items)
  loop
    v_id := nullif(v_item->>'id', '')::bigint;

    if v_id is null then
      continue;
    end if;

    v_patch := v_item
      - 'id'
      - 'created_at'
      - 'updated_at';

    update public.order_items oi
    set (
      order_id,
      shipment_id,
      name,
      image_url,
      price_gbp,
      cost_gbp,
      cost_bdt,
      first_offer_bdt,
      customer_offer_bdt,
      final_offer_bdt,
      product_weight,
      package_weight,
      minimum_quantity,
      product_id,
      ordered_quantity,
      delivered_quantity,
      returned_quantity
    ) = (
      select
        r.order_id,
        r.shipment_id,
        r.name,
        r.image_url,
        r.price_gbp,
        r.cost_gbp,
        r.cost_bdt,
        r.first_offer_bdt,
        r.customer_offer_bdt,
        r.final_offer_bdt,
        r.product_weight,
        r.package_weight,
        r.minimum_quantity,
        r.product_id,
        r.ordered_quantity,
        r.delivered_quantity,
        r.returned_quantity
      from jsonb_populate_record(oi, v_patch) as r
    )
    where oi.id = v_id
    returning oi.* into v_updated;

    if v_updated.id is not null then
      return next v_updated;
    end if;
  end loop;

  return;
end;
$$;

grant execute on function public.bulk_update_order_items(jsonb)
to authenticated;
