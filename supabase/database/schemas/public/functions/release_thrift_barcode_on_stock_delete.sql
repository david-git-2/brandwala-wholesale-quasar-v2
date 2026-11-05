CREATE FUNCTION public.release_thrift_barcode_on_stock_delete()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if old.barcode is not null and trim(old.barcode) <> '' then
    update public.thrift_barcodes
    set status = 'AVAILABLE'
    where tenant_id = old.tenant_id
      and barcode_id = trim(old.barcode);
  end if;

  return old;
end;
$function$;

GRANT ALL ON FUNCTION public.release_thrift_barcode_on_stock_delete() TO anon;

GRANT ALL ON FUNCTION public.release_thrift_barcode_on_stock_delete() TO authenticated;

GRANT ALL ON FUNCTION public.release_thrift_barcode_on_stock_delete() TO service_role;