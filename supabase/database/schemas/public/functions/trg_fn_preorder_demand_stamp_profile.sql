CREATE FUNCTION public.trg_fn_preorder_demand_stamp_profile()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO 'public'
  AS $function$
begin
  if NEW.profile_id is not null then
    return NEW;
  end if;
  if NEW.source_type = 'shop_order_item'::public.preorder_demand_source_type then
    select o.profile_id
    into NEW.profile_id
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    where oi.id = NEW.source_id;
  elsif NEW.source_type = 'pbc_costing_item'::public.preorder_demand_source_type then
    select f.profile_id
    into NEW.profile_id
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    where pci.id = NEW.source_id;
  end if;
  return NEW;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_fn_preorder_demand_stamp_profile() TO anon;

GRANT ALL ON FUNCTION public.trg_fn_preorder_demand_stamp_profile() TO authenticated;

GRANT ALL ON FUNCTION public.trg_fn_preorder_demand_stamp_profile() TO service_role;