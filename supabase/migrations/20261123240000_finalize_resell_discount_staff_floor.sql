-- Staff accept/custom resell may be below unit_minimum_sell_price (customer asked for discount).
-- Floor still applies when staff chooses keep listed resell.

CREATE OR REPLACE FUNCTION public.finalize_dropship_resell_discount_review (
  p_tenant_id bigint,
  p_order_id  bigint,
  p_lines     jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders%rowtype;
  v_line jsonb;
  v_item public.shop_order_items%rowtype;
  v_resolution text;
  v_approved numeric;
  v_currency_id bigint;
  v_required_count integer;
  v_matched_count integer;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant required';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' then
    raise exception 'p_lines must be a jsonb array';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'not a dropship order';
  end if;

  if v_order.status <> 'resell_discount_requested' then
    raise exception 'order is not pending resell discount review';
  end if;

  select count(*) into v_required_count
  from public.shop_order_items soi
  where soi.order_id = p_order_id
    and soi.requested_resell_discount_price_amount is not null;

  select count(*) into v_matched_count
  from jsonb_array_elements(p_lines) el
  join public.shop_order_items soi on soi.id = (el->>'order_item_id')::bigint
  where soi.order_id = p_order_id
    and soi.requested_resell_discount_price_amount is not null
    and el->>'resolution' in ('use_requested', 'use_listed', 'custom');

  if v_matched_count <> v_required_count then
    raise exception 'every line with a discount request must have a resolution';
  end if;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    select * into v_item
    from public.shop_order_items
    where id = (v_line->>'order_item_id')::bigint
      and order_id = p_order_id
    for update;

    if not found or v_item.requested_resell_discount_price_amount is null then
      continue;
    end if;

    v_resolution := v_line->>'resolution';
    v_currency_id := coalesce(
      v_item.customer_sell_price_currency_id,
      v_item.requested_resell_discount_price_currency_id,
      v_item.unit_sell_price_currency_id
    );

    if v_resolution = 'use_requested' then
      v_approved := v_item.requested_resell_discount_price_amount;
    elsif v_resolution = 'use_listed' then
      v_approved := coalesce(v_item.customer_sell_price_amount, v_item.unit_sell_price_amount);
    elsif v_resolution = 'custom' then
      v_approved := (v_line->>'approved_resell_amount')::numeric;
      if v_approved is null then
        raise exception 'approved_resell_amount required for custom resolution on item %', v_item.id;
      end if;
    else
      raise exception 'invalid resolution for item %', v_item.id;
    end if;

    if v_approved is null or v_approved <= 0 then
      raise exception 'approved resell must be positive for item %', v_item.id;
    end if;

    if v_resolution = 'use_listed'
      and coalesce(v_item.unit_minimum_sell_price_amount, 0) > 0
      and v_approved < v_item.unit_minimum_sell_price_amount
    then
      raise exception 'price floor violation on item %', v_item.id;
    end if;

    update public.shop_order_items
    set
      customer_sell_price_amount = v_approved,
      customer_sell_price_currency_id = v_currency_id,
      final_price_amount = v_approved,
      final_price_currency_id = v_currency_id,
      confirmed_quantity = v_item.quantity,
      requested_resell_discount_price_amount = null,
      requested_resell_discount_price_currency_id = null,
      resell_discount_request_reason = null,
      resell_discount_requested_at = null,
      updated_at = now()
    where id = v_item.id;
  end loop;

  update public.shop_order_items soi
  set
    final_price_amount = coalesce(
      soi.final_price_amount,
      soi.customer_sell_price_amount,
      soi.unit_sell_price_amount
    ),
    final_price_currency_id = coalesce(
      soi.final_price_currency_id,
      soi.customer_sell_price_currency_id,
      soi.unit_sell_price_currency_id
    ),
    confirmed_quantity = case
      when coalesce(soi.confirmed_quantity, 0) = 0 then soi.quantity
      else soi.confirmed_quantity
    end,
    updated_at = now()
  where soi.order_id = p_order_id
    and soi.final_price_amount is null;

  update public.shop_orders
  set status = 'confirmed'::public.shop_order_status, updated_at = now()
  where id = p_order_id;

  perform public.recompute_dropship_cod_collect_amount(p_order_id);

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$function$;