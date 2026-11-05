CREATE FUNCTION public.trg_fn_shop_order_write_preorder_demand()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if NEW.shop_type_snapshot = 'vendor_catalog'
    and NEW.status = 'procuring'::public.shop_order_status
    and OLD.status is distinct from NEW.status then
    perform public.ensure_preorder_demand_for_procuring_document('shop_order', NEW.id);
  end if;
  return NEW;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_fn_shop_order_write_preorder_demand() TO anon;

GRANT ALL ON FUNCTION public.trg_fn_shop_order_write_preorder_demand() TO authenticated;

GRANT ALL ON FUNCTION public.trg_fn_shop_order_write_preorder_demand() TO service_role;