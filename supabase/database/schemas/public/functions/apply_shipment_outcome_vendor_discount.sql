CREATE FUNCTION public.apply_shipment_outcome_vendor_discount (
  p_shipment_id        bigint,
  p_source_outcome_id  bigint,
  p_quantity           integer,
  p_new_purchase_price numeric
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
  v_src public.global_shipment_item_outcomes%rowtype;
  v_parent bigint;
  v_prev_price numeric;
  v_credit numeric;
  v_row_id bigint;
begin
  if p_quantity is null or p_quantity < 1 then
    raise exception 'quantity must be at least 1';
  end if;

  if p_new_purchase_price is null or p_new_purchase_price < 0 then
    raise exception 'purchase price must be >= 0';
  end if;

  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  v_parent := v_ship.tenant_id;
  if not public.user_can_manage_parent_tenant(v_parent) then
    raise exception 'not allowed';
  end if;

  if v_ship.status = 'cancelled' then
    raise exception 'shipment is cancelled';
  end if;

  if coalesce(v_ship.is_closed, false) then
    raise exception 'shipment is closed';
  end if;

  if v_ship.status <> 'received' then
    raise exception 'shipment must be received to record vendor credit';
  end if;

  select o.* into v_src
  from public.global_shipment_item_outcomes o
  inner join public.global_shipment_items gsi on gsi.id = o.shipment_item_id
  where o.id = p_source_outcome_id
    and gsi.shipment_id = p_shipment_id;

  if not found then
    raise exception 'outcome not found on shipment';
  end if;

  if v_src.reason = 'ordered'::public.global_shipment_outcome_reason then
    raise exception 'cannot credit ordered row';
  end if;

  if v_src.kind <> 'sellable'::public.global_shipment_outcome_kind then
    raise exception 'outcome must be sellable';
  end if;

  if p_quantity > v_src.quantity then
    raise exception 'quantity % exceeds split qty %', p_quantity, v_src.quantity;
  end if;

  v_prev_price := coalesce(v_src.purchase_price, 0);
  v_credit := round((v_prev_price - p_new_purchase_price) * p_quantity, 4);

  insert into public.global_shipment_outcome_vendor_credits (
    tenant_id,
    shipment_id,
    shipment_item_id,
    outcome_id,
    quantity,
    previous_purchase_price,
    new_purchase_price,
    credit_amount,
    created_by_email
  ) values (
    v_parent,
    p_shipment_id,
    v_src.shipment_item_id,
    v_src.id,
    p_quantity,
    v_prev_price,
    p_new_purchase_price,
    v_credit,
    public.current_user_email()
  )
  returning id into v_row_id;

  return jsonb_build_object(
    'mode', 'record',
    'id', v_row_id,
    'shipment_id', p_shipment_id,
    'outcome_id', v_src.id,
    'quantity', p_quantity,
    'previous_purchase_price', v_prev_price,
    'new_purchase_price', p_new_purchase_price,
    'credit_amount', v_credit
  );
end;
$function$;

GRANT ALL ON FUNCTION public.apply_shipment_outcome_vendor_discount(bigint, bigint, integer, numeric) TO anon;

GRANT ALL ON FUNCTION public.apply_shipment_outcome_vendor_discount(bigint, bigint, integer, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.apply_shipment_outcome_vendor_discount(bigint, bigint, integer, numeric) TO service_role;