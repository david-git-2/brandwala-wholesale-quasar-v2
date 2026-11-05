CREATE FUNCTION public.normalize_costing_file_status_po_placed()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if new.status::text = 'completed' then
    new.status = 'po_placed'::public.costing_file_status;
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.normalize_costing_file_status_po_placed() TO anon;

GRANT ALL ON FUNCTION public.normalize_costing_file_status_po_placed() TO authenticated;

GRANT ALL ON FUNCTION public.normalize_costing_file_status_po_placed() TO service_role;