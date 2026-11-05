CREATE FUNCTION public.trg_reactive_adjust_child_listing_cost()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_new_landed_cost numeric;
begin
  if new.purchase_price <> old.purchase_price or coalesce(new.landed_cost_bdt, -1) <> coalesce(old.landed_cost_bdt, -1) then
    v_new_landed_cost := coalesce(new.landed_cost_bdt, round(new.purchase_price, 2));

    update public.shop_product_listings spl
    set
      minimum_sell_price_amount = case
        when spl.is_price_locked is true then spl.minimum_sell_price_amount
        else v_new_landed_cost
      end,
      sell_price_amount = case
        when spl.is_price_locked is true then spl.sell_price_amount
        else greatest(spl.sell_price_amount, v_new_landed_cost)
      end,
      updated_at = now()
    from public.global_stocks gs
    where spl.global_stock_id = gs.id
      and gs.shipment_item_id = new.id;
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_reactive_adjust_child_listing_cost() TO anon;

GRANT ALL ON FUNCTION public.trg_reactive_adjust_child_listing_cost() TO authenticated;

GRANT ALL ON FUNCTION public.trg_reactive_adjust_child_listing_cost() TO service_role;