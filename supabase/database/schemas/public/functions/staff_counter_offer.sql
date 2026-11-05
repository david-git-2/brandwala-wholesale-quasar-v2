CREATE FUNCTION public.staff_counter_offer (
  p_order_id bigint,
  p_items    jsonb
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
  v_item record;
begin
  select tenant_id into v_tenant_id from public.shop_orders where id = p_order_id;
  
  if v_tenant_id is null then
    raise exception 'order not found';
  end if;

  if not public.is_tenant_staff(v_tenant_id) then
    raise exception 'access denied';
  end if;

  for v_item in select * from jsonb_to_recordset(p_items) as x(id bigint, staff_offer_amount numeric, staff_offer_currency_id bigint) loop
    update public.shop_order_items
    set
      staff_offer_amount = v_item.staff_offer_amount,
      staff_offer_currency_id = v_item.staff_offer_currency_id
    where id = v_item.id and order_id = p_order_id;
  end loop;

  update public.shop_orders
  set
    status = 'negotiating',
    updated_at = now()
  where id = p_order_id;
end;
$function$;

GRANT ALL ON FUNCTION public.staff_counter_offer(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.staff_counter_offer(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.staff_counter_offer(bigint, jsonb) TO service_role;