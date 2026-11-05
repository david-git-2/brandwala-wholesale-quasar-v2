CREATE FUNCTION public.trg_fn_pbc_file_write_preorder_demand()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if public.normalize_pbc_procurement_status(NEW.status) = 'procuring'
    and public.normalize_pbc_procurement_status(OLD.status) is distinct from 'procuring' then
    perform public.ensure_preorder_demand_for_procuring_document('pbc_costing_file', NEW.id);
  end if;
  return NEW;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_fn_pbc_file_write_preorder_demand() TO anon;

GRANT ALL ON FUNCTION public.trg_fn_pbc_file_write_preorder_demand() TO authenticated;

GRANT ALL ON FUNCTION public.trg_fn_pbc_file_write_preorder_demand() TO service_role;