CREATE FUNCTION public.trg_auto_publish_dropship_listing()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_shop record;
  v_rule record;
  v_landed_cost numeric;
  v_currency_id bigint;
  v_product_id bigint;
  v_stock_id bigint;
  v_sell_price numeric;
begin
  -- For each shop owned by the target child tenant that has auto_publish enabled
  for v_shop in (
    select s.id as shop_id, s.tenant_id
    from public.shops s
    where s.tenant_id = new.tenant_id
  ) loop
    select * into v_rule
    from public.shop_pricing_rules
    where shop_id = v_shop.shop_id;

    if v_rule.is_auto_publish is true then
      -- Calculate parent landed cost for minimum_sell_price
      select
        (gsi.purchase_price * coalesce(gship.product_conversion_rate, 1.0)),
        gsi.purchase_price_currency_id,
        gsi.product_id,
        gs.id
      into v_landed_cost, v_currency_id, v_product_id, v_stock_id
      from public.global_stocks gs
      join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      join public.global_shipments gship on gship.id = gsi.shipment_id
      where gs.id = new.stock_id;

      if v_landed_cost is not null and v_currency_id is not null then
        v_sell_price := round(v_landed_cost * (1 + (coalesce(v_rule.markup_percentage, 0.00) / 100.0)), 2);

        insert into public.shop_product_listings (
          tenant_id,
          shop_id,
          global_stock_allocation_id,
          global_stock_id,
          product_id,
          sell_price_amount,
          sell_price_currency_id,
          minimum_sell_price_amount,
          minimum_sell_price_currency_id,
          is_active
        )
        values (
          v_shop.tenant_id,
          v_shop.shop_id,
          new.id,
          v_stock_id,
          v_product_id,
          v_sell_price,
          v_currency_id,
          round(v_landed_cost, 2),
          v_currency_id,
          true
        )
        on conflict (shop_id, global_stock_allocation_id) do update set
          minimum_sell_price_amount = excluded.minimum_sell_price_amount,
          minimum_sell_price_currency_id = excluded.minimum_sell_price_currency_id,
          sell_price_amount = case
            when shop_product_listings.sell_price_amount < excluded.minimum_sell_price_amount then excluded.sell_price_amount
            else shop_product_listings.sell_price_amount
          end,
          updated_at = now();
      end if;
    end if;
  end loop;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_auto_publish_dropship_listing() TO anon;

GRANT ALL ON FUNCTION public.trg_auto_publish_dropship_listing() TO authenticated;

GRANT ALL ON FUNCTION public.trg_auto_publish_dropship_listing() TO service_role;