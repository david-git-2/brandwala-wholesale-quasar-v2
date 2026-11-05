CREATE FUNCTION public.set_order_item_product_identity()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_product record;
begin
  if new.product_id is null then
    return new;
  end if;

  select p.barcode, p.product_code
  into v_product
  from public.products p
  where p.id = new.product_id;

  if found then
    new.barcode := coalesce(new.barcode, v_product.barcode);
    new.product_code := coalesce(new.product_code, v_product.product_code);
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.set_order_item_product_identity() TO anon;

GRANT ALL ON FUNCTION public.set_order_item_product_identity() TO authenticated;

GRANT ALL ON FUNCTION public.set_order_item_product_identity() TO service_role;