-- F7: Commerce RPCs retargeted to global_stock_id
begin;

drop function if exists public.add_item_to_commerce_cart(bigint, bigint, bigint, integer);

create or replace function public.add_item_to_commerce_cart(
  p_tenant_id bigint,
  p_customer_group_id bigint,
  p_global_stock_id bigint,
  p_quantity integer default 1
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing public.commerce_cart;
  v_row public.commerce_cart;
  v_product_id bigint;
  v_parent_id bigint;
begin
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select product_id into v_product_id
  from public.global_stocks
  where id = p_global_stock_id
    and parent_tenant_id = v_parent_id;

  if v_product_id is null and not exists (
    select 1 from public.global_stocks where id = p_global_stock_id and parent_tenant_id = v_parent_id
  ) then
    raise exception 'global stock not found for tenant parent';
  end if;

  select *
  into v_existing
  from public.commerce_cart
  where tenant_id = p_tenant_id
    and customer_group_id = p_customer_group_id
    and global_stock_id = p_global_stock_id
  limit 1;

  if v_existing.id is not null then
    update public.commerce_cart
    set quantity = v_existing.quantity + greatest(p_quantity, 1),
        updated_at = now()
    where id = v_existing.id
    returning * into v_row;
  else
    insert into public.commerce_cart (
      tenant_id,
      customer_group_id,
      global_stock_id,
      inventory_item_id,
      product_id,
      quantity
    )
    values (
      p_tenant_id,
      p_customer_group_id,
      p_global_stock_id,
      null,
      v_product_id,
      greatest(p_quantity, 1)
    )
    returning * into v_row;
  end if;

  return to_jsonb(v_row);
end;
$$;

grant execute on function public.add_item_to_commerce_cart(bigint, bigint, bigint, integer) to authenticated;

create or replace function public.list_commerce_global_stock_for_store(
  p_tenant_id bigint,
  p_store_id bigint,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_parent_id bigint;
  v_rows jsonb;
begin
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into v_rows
  from (
    select
      gs.id as global_stock_id,
      gs.name,
      gs.barcode,
      gs.product_code,
      gs.image_url,
      gs.cost,
      gs.product_id,
      coalesce(sum(q.quantity) filter (where q.status in ('excellent', 'box_less')), 0)::integer as available_qty,
      spp.price_bdt,
      spp.minimum_sell_price_bdt
    from public.global_stocks gs
    left join public.global_stock_quantities q on q.stock_id = gs.id
    left join public.store_product_prices spp
      on spp.global_stock_id = gs.id and spp.store_id = p_store_id
    left join public.child_tenant_stock_allocations a
      on a.stock_id = gs.id and a.child_tenant_id = p_tenant_id
    where gs.parent_tenant_id = v_parent_id
      and gs.status = 'active'
      and (
        p_tenant_id = v_parent_id
        or a.quantity > 0
        or a.id is null
      )
      and (
        p_search is null or trim(p_search) = ''
        or gs.name ilike '%' || trim(p_search) || '%'
        or coalesce(gs.barcode, '') ilike '%' || trim(p_search) || '%'
      )
    group by gs.id, spp.price_bdt, spp.minimum_sell_price_bdt
    having coalesce(sum(q.quantity) filter (where q.status in ('excellent', 'box_less')), 0) > 0
    order by gs.id desc
    limit greatest(coalesce(p_limit, 50), 1)
    offset greatest(coalesce(p_offset, 0), 0)
  ) t;

  return jsonb_build_object('items', coalesce(v_rows, '[]'::jsonb));
end;
$$;

grant execute on function public.list_commerce_global_stock_for_store(bigint, bigint, text, integer, integer) to authenticated;

commit;
