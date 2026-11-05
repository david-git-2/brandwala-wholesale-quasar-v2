CREATE FUNCTION public.compute_dropship_settlement_totals (
  p_collected_cod          numeric,
  p_reseller_purchase_cost numeric,
  p_discount_company_pay   numeric,
  p_charge_lines           jsonb
)
  RETURNS TABLE (
    total_cost            numeric,
    reseller_profit       numeric,
    company_profit        numeric,
    merchant_paid_charges numeric
  )
  LANGUAGE plpgsql
  IMMUTABLE
  AS $function$
declare
  v_charge_sum numeric := 0;
  v_merchant_paid numeric := 0;
  v_line jsonb;
begin
  if p_charge_lines is not null and jsonb_typeof(p_charge_lines) = 'array' then
    for v_line in select value from jsonb_array_elements(p_charge_lines)
    loop
      v_charge_sum := v_charge_sum + coalesce((v_line->>'amount')::numeric, 0);
      if coalesce(v_line->>'payer', '') = 'merchant' then
        v_merchant_paid := v_merchant_paid + coalesce((v_line->>'amount')::numeric, 0);
      end if;
    end loop;
  end if;

  total_cost := coalesce(p_reseller_purchase_cost, 0) + v_charge_sum;
  merchant_paid_charges := v_merchant_paid;
  reseller_profit := coalesce(p_collected_cod, 0) - coalesce(p_reseller_purchase_cost, 0) - v_merchant_paid;
  company_profit := reseller_profit - coalesce(p_discount_company_pay, 0);
  return next;
end;
$function$;

CREATE FUNCTION public.compute_dropship_settlement_totals (
  p_items_resell_total       numeric,
  p_order_discount_amount    numeric,
  p_reseller_purchase_cost   numeric,
  p_company_procurement_cost numeric,
  p_discount_company_pay     numeric,
  p_charge_lines             jsonb
)
  RETURNS TABLE (
    total_cost            numeric,
    reseller_profit       numeric,
    company_profit        numeric,
    merchant_paid_charges numeric
  )
  LANGUAGE plpgsql
  IMMUTABLE
  SET search_path TO 'public'
  AS $function$
declare
  v_charge_sum numeric := 0;
  v_merchant_paid numeric := 0;
  v_line jsonb;
begin
  if p_charge_lines is not null and jsonb_typeof(p_charge_lines) = 'array' then
    for v_line in select value from jsonb_array_elements(p_charge_lines)
    loop
      v_charge_sum := v_charge_sum + coalesce((v_line->>'amount')::numeric, 0);
      if coalesce(v_line->>'payer', '') = 'merchant' then
        v_merchant_paid := v_merchant_paid + coalesce((v_line->>'amount')::numeric, 0);
      end if;
    end loop;
  end if;

  total_cost := coalesce(p_company_procurement_cost, 0) + v_charge_sum;
  merchant_paid_charges := v_merchant_paid;
  reseller_profit :=
    coalesce(p_items_resell_total, 0)
    - coalesce(p_order_discount_amount, 0)
    - coalesce(p_reseller_purchase_cost, 0)
    - v_merchant_paid;
  company_profit :=
    coalesce(p_reseller_purchase_cost, 0)
    - coalesce(p_company_procurement_cost, 0)
    - coalesce(p_discount_company_pay, 0);
  return next;
end;
$function$;

GRANT ALL ON FUNCTION public.compute_dropship_settlement_totals(numeric, numeric, numeric, jsonb) TO anon;

GRANT ALL ON FUNCTION public.compute_dropship_settlement_totals(numeric, numeric, numeric, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.compute_dropship_settlement_totals(numeric, numeric, numeric, jsonb) TO service_role;

GRANT ALL ON FUNCTION public.compute_dropship_settlement_totals(numeric, numeric, numeric, numeric, numeric, jsonb) TO anon;

GRANT ALL ON FUNCTION public.compute_dropship_settlement_totals(numeric, numeric, numeric, numeric, numeric, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.compute_dropship_settlement_totals(numeric, numeric, numeric, numeric, numeric, jsonb) TO service_role;