-- Demand buy order line unit price: same cost basis as get_shop_order_for_staff pricing.cost.

CREATE OR REPLACE FUNCTION public.shop_order_item_demand_buy_unit_price (
  p_cost_price_amount          numeric,
  p_unit_list_price_amount     numeric,
  p_reference_cost_amount      numeric,
  p_is_negotiable_snapshot     boolean DEFAULT NULL,
  p_staff_offer_amount         numeric DEFAULT NULL,
  p_final_price_amount         numeric DEFAULT NULL,
  p_unit_sell_price_amount     numeric DEFAULT NULL,
  p_customer_sell_price_amount numeric DEFAULT NULL
)
  RETURNS numeric
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  SELECT nullif(
    coalesce(
      nullif(p_cost_price_amount, 0),
      nullif(p_unit_list_price_amount, 0),
      nullif(p_reference_cost_amount, 0),
      nullif(
        public.shop_order_item_delivery_sell_price(
          p_is_negotiable_snapshot,
          p_staff_offer_amount,
          p_final_price_amount,
          p_unit_sell_price_amount,
          p_customer_sell_price_amount,
          p_unit_list_price_amount
        ),
        0
      )
    ),
    0
  )::numeric(12, 2);
$function$;

GRANT ALL ON FUNCTION public.shop_order_item_demand_buy_unit_price(
  numeric, numeric, numeric, boolean, numeric, numeric, numeric, numeric
) TO anon;

GRANT ALL ON FUNCTION public.shop_order_item_demand_buy_unit_price(
  numeric, numeric, numeric, boolean, numeric, numeric, numeric, numeric
) TO authenticated;

GRANT ALL ON FUNCTION public.shop_order_item_demand_buy_unit_price(
  numeric, numeric, numeric, boolean, numeric, numeric, numeric, numeric
) TO service_role;