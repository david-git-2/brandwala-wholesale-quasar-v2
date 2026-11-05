CREATE FUNCTION public.apply_dropship_order_charge_lines (
  p_order_id     bigint,
  p_charge_lines jsonb
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_line jsonb;
  v_delivery_amount numeric(12,2);
  v_print_amount numeric(12,2);
  v_packing_amount numeric(12,2);
  v_cod_amount numeric(12,2);
  v_deduct_delivery boolean;
  v_deduct_print boolean;
  v_deduct_packing boolean;
  v_deduct_cod boolean;
  v_has_delivery boolean := false;
  v_has_print boolean := false;
  v_has_packing boolean := false;
  v_has_cod boolean := false;
begin
  if p_charge_lines is null or jsonb_typeof(p_charge_lines) <> 'array' then
    return;
  end if;

  for v_line in select value from jsonb_array_elements(p_charge_lines)
  loop
    case coalesce(v_line->>'charge_type', '')
      when 'delivery' then
        v_delivery_amount := greatest(coalesce((v_line->>'amount')::numeric, 0), 0);
        v_deduct_delivery := coalesce(v_line->>'payer', '') = 'merchant';
        v_has_delivery := true;
      when 'print' then
        v_print_amount := greatest(coalesce((v_line->>'amount')::numeric, 0), 0);
        v_deduct_print := coalesce(v_line->>'payer', '') = 'merchant';
        v_has_print := true;
      when 'packing' then
        v_packing_amount := greatest(coalesce((v_line->>'amount')::numeric, 0), 0);
        v_deduct_packing := coalesce(v_line->>'payer', '') = 'merchant';
        v_has_packing := true;
      when 'cod' then
        v_cod_amount := greatest(coalesce((v_line->>'amount')::numeric, 0), 0);
        v_deduct_cod := coalesce(v_line->>'payer', '') = 'merchant';
        v_has_cod := true;
      else
        null;
    end case;
  end loop;

  if not (v_has_delivery or v_has_print or v_has_packing or v_has_cod) then
    return;
  end if;

  update public.shop_orders o
  set
    delivery_charge_amount = case when v_has_delivery then v_delivery_amount else o.delivery_charge_amount end,
    print_charge_amount = case when v_has_print then v_print_amount else o.print_charge_amount end,
    packing_charge_amount = case when v_has_packing then v_packing_amount else o.packing_charge_amount end,
    cod_charge_amount = case when v_has_cod then v_cod_amount else o.cod_charge_amount end,
    deduct_delivery_from_margin = case when v_has_delivery then v_deduct_delivery else o.deduct_delivery_from_margin end,
    deduct_print_from_margin = case when v_has_print then v_deduct_print else o.deduct_print_from_margin end,
    deduct_packing_from_margin = case when v_has_packing then v_deduct_packing else o.deduct_packing_from_margin end,
    deduct_cod_from_margin = case when v_has_cod then v_deduct_cod else o.deduct_cod_from_margin end,
    updated_at = now()
  where o.id = p_order_id;

  if not found then
    raise exception 'order not found';
  end if;
end;
$function$;

GRANT ALL ON FUNCTION public.apply_dropship_order_charge_lines(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.apply_dropship_order_charge_lines(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.apply_dropship_order_charge_lines(bigint, jsonb) TO service_role;