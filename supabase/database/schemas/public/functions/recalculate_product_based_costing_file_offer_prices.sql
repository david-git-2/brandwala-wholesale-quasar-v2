CREATE FUNCTION public.recalculate_product_based_costing_file_offer_prices (
  p_file_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
declare
  v_conversion_rate numeric;
  v_cargo_rate numeric;
  v_profit_rate numeric;
  v_vat_rate numeric;
  v_offer_pricing_mode text;
begin
  select conversion_rate, cargo_rate_kg_gbp, profit_rate, vat_rate, offer_pricing_mode::text
    into v_conversion_rate, v_cargo_rate, v_profit_rate, v_vat_rate, v_offer_pricing_mode
    from public.product_based_costing_files
   where id = p_file_id;

  update public.product_based_costing_items
     set offer_price = public.pbc_calculated_offer_price_bdt(
           coalesce(price_gbp, 0),
           coalesce(product_weight, 0),
           coalesce(package_weight, 0),
           coalesce(v_cargo_rate, 0),
           coalesce(v_conversion_rate, 140),
           coalesce(v_profit_rate, 25),
           coalesce(v_vat_rate, 0),
           coalesce(v_offer_pricing_mode, 'landed_cost_plus')
         ),
         is_offer_price_manual = false
   where product_based_costing_file_id = p_file_id
     and (is_offer_price_manual is not true);
end;
$function$;

GRANT ALL ON FUNCTION public.recalculate_product_based_costing_file_offer_prices(bigint) TO anon;

GRANT ALL ON FUNCTION public.recalculate_product_based_costing_file_offer_prices(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.recalculate_product_based_costing_file_offer_prices(bigint) TO service_role;