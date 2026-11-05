CREATE FUNCTION public.get_dropship_merchant_billable_charges (
  p_order_id bigint
)
  RETURNS TABLE (
    delivery numeric,
    print    numeric,
    packing  numeric,
    cod      numeric
  )
  LANGUAGE plpgsql
  STABLE
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders;
  v_settlement_id bigint;
  v_lines jsonb;
  v_line jsonb;
  v_delivery numeric := 0;
  v_print numeric := 0;
  v_packing numeric := 0;
  v_cod numeric := 0;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    delivery := 0;
    print := 0;
    packing := 0;
    cod := 0;
    return next;
    return;
  end if;

  select s.id into v_settlement_id
  from public.dropship_order_settlements s
  where s.shop_order_id = p_order_id;

  if v_settlement_id is not null then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'charge_type', cl.charge_type,
          'amount', cl.amount,
          'payer', cl.payer
        )
      ),
      '[]'::jsonb
    )
    into v_lines
    from public.dropship_settlement_charge_lines cl
    where cl.settlement_id = v_settlement_id
      and cl.charge_type in ('delivery', 'print', 'packing', 'cod');
  else
    v_lines := public.build_default_dropship_settlement_charge_lines(v_order);
  end if;

  for v_line in
    select value from jsonb_array_elements(coalesce(v_lines, '[]'::jsonb))
  loop
    if coalesce(v_line->>'payer', '') = 'merchant' then
      case v_line->>'charge_type'
        when 'delivery' then
          v_delivery := coalesce((v_line->>'amount')::numeric, 0);
        when 'print' then
          v_print := coalesce((v_line->>'amount')::numeric, 0);
        when 'packing' then
          v_packing := coalesce((v_line->>'amount')::numeric, 0);
        when 'cod' then
          v_cod := coalesce((v_line->>'amount')::numeric, 0);
        else
          null;
      end case;
    end if;
  end loop;

  delivery := v_delivery;
  print := v_print;
  packing := v_packing;
  cod := v_cod;
  return next;
end;
$function$;

GRANT ALL ON FUNCTION public.get_dropship_merchant_billable_charges(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_dropship_merchant_billable_charges(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_dropship_merchant_billable_charges(bigint) TO service_role;