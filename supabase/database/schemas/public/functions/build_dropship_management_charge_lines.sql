CREATE FUNCTION public.build_dropship_management_charge_lines (
  p_order         public.shop_orders,
  p_settlement_id bigint             DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SET search_path TO 'public'
  AS $function$
declare
  v_default_lines jsonb;
  v_return_line jsonb;
begin
  v_default_lines := public.build_default_dropship_settlement_charge_lines(p_order);

  if p_settlement_id is not null then
    select jsonb_build_object(
      'charge_type', cl.charge_type,
      'amount', cl.amount,
      'payer', cl.payer
    )
    into v_return_line
    from public.dropship_settlement_charge_lines cl
    where cl.settlement_id = p_settlement_id
      and cl.charge_type = 'return';
  end if;

  if v_return_line is null then
    select elem.value
    into v_return_line
    from jsonb_array_elements(v_default_lines) elem(value)
    where elem.value->>'charge_type' = 'return';
  end if;

  return coalesce(
    (
      select jsonb_agg(elem.value order by elem.value->>'charge_type')
      from jsonb_array_elements(v_default_lines) elem(value)
      where elem.value->>'charge_type' in ('cod', 'delivery', 'packing', 'print')
    ),
    '[]'::jsonb
  ) || jsonb_build_array(coalesce(v_return_line, jsonb_build_object(
    'charge_type', 'return',
    'amount', coalesce(p_order.return_charge_amount, 0),
    'payer', case when coalesce(p_order.deduct_return_charge_from_middle_man, true) then 'merchant' else 'company' end
  )));
end;
$function$;

GRANT ALL ON FUNCTION public.build_dropship_management_charge_lines(public.shop_orders, bigint) TO anon;

GRANT ALL ON FUNCTION public.build_dropship_management_charge_lines(public.shop_orders, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.build_dropship_management_charge_lines(public.shop_orders, bigint) TO service_role;