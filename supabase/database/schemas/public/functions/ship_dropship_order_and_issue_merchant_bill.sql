CREATE FUNCTION public.ship_dropship_order_and_issue_merchant_bill (
  p_tenant_id bigint,
  p_order_id  bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders;
  v_issue jsonb;
  v_ap jsonb;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.tenant_id is distinct from p_tenant_id
     and v_order.parent_tenant_id is distinct from p_tenant_id then
    return jsonb_build_object('success', false, 'error', 'tenant mismatch');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'order is not a dropship order');
  end if;

  if v_order.status <> 'ready_for_pickup'::public.shop_order_status then
    return jsonb_build_object(
      'success', false,
      'error', format('ship requires ready_for_pickup (current: %s)', v_order.status)
    );
  end if;

  if v_order.profile_id is null then
    return jsonb_build_object('success', false, 'error', 'billing profile is required before ship');
  end if;

  if v_order.courier_service_id is null then
    return jsonb_build_object('success', false, 'error', 'courier is required before ship');
  end if;

  if nullif(trim(coalesce(v_order.sender_name, '')), '') is null
     or nullif(trim(coalesce(v_order.pickup_phone, '')), '') is null
     or nullif(trim(coalesce(v_order.pickup_address, '')), '') is null then
    return jsonb_build_object('success', false, 'error', 'pickup location name, phone, and address are required before ship');
  end if;

  if exists (
    select 1
    from public.shop_order_items soi
    where soi.order_id = p_order_id
      and soi.quantity > 0
      and coalesce(soi.is_fulfillment_unavailable, false) = false
      and coalesce(soi.confirmed_quantity, 0) <= 0
      and not (
        coalesce(soi.is_gift, false)
        and soi.gift_source = 'stock'
      )
      and not (
        coalesce(soi.is_gift, false)
        and soi.gift_source = 'customer_stock'
        and coalesce(soi.confirmed_quantity, 0) >= soi.quantity
      )
      and not exists (
        select 1
        from public.shop_order_item_stock_picks sp
        where sp.order_item_id = soi.id
          and sp.quantity > 0
      )
  ) then
    return jsonb_build_object('success', false, 'error', 'every line must be picked or marked unavailable before ship');
  end if;

  v_issue := public.issue_dropship_tenant_b2b_invoice(p_tenant_id, p_order_id);
  if coalesce(v_issue->>'success', 'false') <> 'true' then
    return v_issue;
  end if;

  v_ap := public.upsert_dropship_courier_ap_bill(p_order_id, false);
  if coalesce(v_ap->>'success', 'false') <> 'true' then
    return v_ap;
  end if;
  if nullif(v_ap->>'bill_id', '') is null then
    return jsonb_build_object('success', false, 'error', 'courier bill was not created');
  end if;

  update public.shop_orders
  set
    status = 'shipped'::public.shop_order_status,
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'new_status', 'shipped',
    'invoice', v_issue->'invoice',
    'courier_ap', v_ap,
    'created', coalesce(v_issue->>'created', 'false')::boolean,
    'already_issued', coalesce(v_issue->>'already_issued', 'false')::boolean
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$function$;

GRANT ALL ON FUNCTION public.ship_dropship_order_and_issue_merchant_bill(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.ship_dropship_order_and_issue_merchant_bill(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.ship_dropship_order_and_issue_merchant_bill(bigint, bigint) TO service_role;