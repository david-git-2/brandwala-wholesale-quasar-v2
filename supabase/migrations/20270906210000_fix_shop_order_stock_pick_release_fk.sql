-- Fix FK violation: shop_order_item_stock_picks.held_stock_id blocks held-row delete during release.
-- Clear pick references before moving held stock back to sellable.

begin;

create or replace function public.remove_shop_order_item_stock_pick(p_pick_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pick public.shop_order_item_stock_picks%rowtype;
  v_order public.shop_orders%rowtype;
  v_stock public.global_stocks%rowtype;
  v_parent_tenant_id bigint;
  v_held_stock_id bigint;
  v_release_qty integer;
begin
  select * into v_pick from public.shop_order_item_stock_picks where id = p_pick_id for update;
  if v_pick.id is null then
    raise exception 'pick not found';
  end if;

  select * into v_order from public.shop_orders where id = v_pick.order_id for update;
  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status <> 'processing'::public.shop_order_status then
    raise exception 'pick removal is only allowed while order is processing';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);
  v_held_stock_id := v_pick.held_stock_id;
  v_release_qty := v_pick.quantity;

  delete from public.shop_order_item_stock_picks where id = p_pick_id;

  perform public._recompute_shop_order_item_fulfillment(v_pick.order_item_id);
  perform public.recompute_dropship_cod_collect_amount(v_order.id);

  if v_held_stock_id is not null then
    select * into v_stock from public.global_stocks where id = v_held_stock_id for update;
    if found
       and v_stock.availability = 'held'::public.stock_availability
       and v_stock.quantity >= v_release_qty then
      perform public.create_and_post_stock_movement(
        p_tenant_id => v_parent_tenant_id,
        p_stock_id => v_stock.id,
        p_quantity => v_release_qty,
        p_to_location_id => v_stock.location_id,
        p_to_availability => 'sellable'::public.stock_availability,
        p_to_grade_tag_id => v_stock.grade_tag_id,
        p_movement_type => 'availability_transfer'::public.stock_movement_type,
        p_notes => 'Undo dropship processing pick',
        p_reference_type => 'shop_order',
        p_reference_id => v_order.id::text
      );
    end if;
  end if;

  return jsonb_build_object('success', true);
end;
$$;

create or replace function public.release_dropship_order_stock(
  p_order_id bigint,
  p_restore_display boolean default true
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders%rowtype;
  v_item record;
  v_pick record;
  v_skip_stock_release boolean := false;
  v_invoice_status public.global_invoice_status;
  v_parent_tenant_id bigint;
  v_stock public.global_stocks%rowtype;
  v_new_override_qty integer;
  v_new_sellable_qty integer;
  v_grade_tag_id bigint;
  v_held_stock_id bigint;
  v_release_qty integer;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then return; end if;

  if coalesce(v_order.shop_type_snapshot, (
    select shop_type from public.shops where id = v_order.shop_id
  )) <> 'dropship' then
    return;
  end if;

  if v_order.global_invoice_id is not null then
    select invoice_status into v_invoice_status
    from public.global_invoices where id = v_order.global_invoice_id;
    if v_invoice_status = 'issued'::public.global_invoice_status then
      v_skip_stock_release := true;
    end if;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  if not v_skip_stock_release then
    for v_pick in
      select * from public.shop_order_item_stock_picks where order_id = p_order_id
    loop
      if v_pick.held_stock_id is null then continue; end if;

      v_held_stock_id := v_pick.held_stock_id;
      v_release_qty := v_pick.quantity;

      update public.shop_order_item_stock_picks
      set held_stock_id = null, updated_at = now()
      where id = v_pick.id;

      select * into v_stock from public.global_stocks where id = v_held_stock_id for update;
      if found
         and v_stock.availability = 'held'::public.stock_availability
         and v_stock.quantity >= v_release_qty then
        perform public.create_and_post_stock_movement(
          p_tenant_id => v_parent_tenant_id,
          p_stock_id => v_stock.id,
          p_quantity => v_release_qty,
          p_to_location_id => v_stock.location_id,
          p_to_availability => 'sellable'::public.stock_availability,
          p_to_grade_tag_id => v_stock.grade_tag_id,
          p_movement_type => 'availability_transfer'::public.stock_movement_type,
          p_notes => 'Dropship order release (pick)',
          p_reference_type => 'shop_order',
          p_reference_id => p_order_id::text
        );
      end if;
    end loop;
  end if;

  for v_item in select * from public.shop_order_items where order_id = p_order_id
  loop
    v_grade_tag_id := coalesce(
      v_item.grade_tag_id,
      (select gs.grade_tag_id from public.global_stocks gs where gs.id = v_item.global_stock_id),
      public.default_stock_grade_tag_id()
    );

    if p_restore_display then
      if v_item.listing_id is not null then
        update public.shop_product_listings
        set display_quantity_override = display_quantity_override + v_item.quantity
        where id = v_item.listing_id and display_quantity_override is not null;
      end if;
    end if;

    if not v_skip_stock_release
       and v_item.global_stock_id is not null
       and not exists (
         select 1 from public.shop_order_item_stock_picks sp
         where sp.order_item_id = v_item.id
       ) then
      select * into v_stock from public.global_stocks where id = v_item.global_stock_id for update;
      if found
         and v_stock.availability = 'held'::public.stock_availability
         and v_stock.quantity >= coalesce(v_item.confirmed_quantity, v_item.quantity) then
        perform public.create_and_post_stock_movement(
          p_tenant_id => v_parent_tenant_id,
          p_stock_id => v_stock.id,
          p_quantity => coalesce(v_item.confirmed_quantity, v_item.quantity),
          p_to_location_id => v_stock.location_id,
          p_to_availability => 'sellable'::public.stock_availability,
          p_to_grade_tag_id => v_stock.grade_tag_id,
          p_movement_type => 'availability_transfer'::public.stock_movement_type,
          p_notes => 'Dropship order release (legacy line)',
          p_reference_type => 'shop_order',
          p_reference_id => p_order_id::text
        );
      end if;
    end if;

    if v_item.listing_id is not null then
      v_new_sellable_qty := public.shop_product_grade_available_units(
        v_order.tenant_id, v_item.product_id, v_grade_tag_id
      );
      select display_quantity_override into v_new_override_qty
      from public.shop_product_listings where id = v_item.listing_id;
      if coalesce(v_new_override_qty, v_new_sellable_qty, 0) > 0 then
        update public.shop_product_listings set is_active = true where id = v_item.listing_id;
      end if;
    end if;
  end loop;
end;
$$;

commit;
