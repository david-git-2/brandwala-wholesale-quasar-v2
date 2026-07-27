-- RPC to recalculate offer prices for all unlocked items in a product based costing file in a single transaction
create or replace function public.recalculate_product_based_costing_file_offer_prices(
  p_file_id bigint
)
returns void
language plpgsql
security definer
as $$
declare
  v_conversion_rate numeric;
  v_cargo_rate numeric;
  v_profit_rate numeric;
begin
  select conversion_rate, cargo_rate_kg_gbp, profit_rate
    into v_conversion_rate, v_cargo_rate, v_profit_rate
    from public.product_based_costing_files
   where id = p_file_id;

  update public.product_based_costing_items
     set offer_price = public.round_bdt_up_to_zero_or_five(
           ceil(
             round(
               (coalesce(price_gbp, 0) + ((coalesce(product_weight, 0) + coalesce(package_weight, 0)) / 1000.0) * coalesce(v_cargo_rate, 0)),
               2
             ) * coalesce(v_conversion_rate, 140) - 1e-9
           ) + (
             ceil(
               round(
                 (coalesce(price_gbp, 0) + ((coalesce(product_weight, 0) + coalesce(package_weight, 0)) / 1000.0) * coalesce(v_cargo_rate, 0)),
                 2
               ) * coalesce(v_conversion_rate, 140) - 1e-9
             ) * coalesce(v_profit_rate, 25) / 100.0
           )
         ),
         is_offer_price_manual = false
   where product_based_costing_file_id = p_file_id
     and (is_offer_price_manual is not true);
end;
$$;

grant execute on function public.recalculate_product_based_costing_file_offer_prices(bigint) to authenticated;
grant execute on function public.recalculate_product_based_costing_file_offer_prices(bigint) to service_role;
