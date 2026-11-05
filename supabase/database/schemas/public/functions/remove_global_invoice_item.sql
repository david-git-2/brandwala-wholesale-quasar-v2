CREATE FUNCTION public.remove_global_invoice_item (
  p_invoice_item_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_invoice public.bills;
begin
  select gi.* into v_invoice
  from public.bills gi
  inner join public.global_invoice_items gii on gii.invoice_id = gi.id
  where gii.id = p_invoice_item_id;

  if v_invoice.id is null then raise exception 'item not found'; end if;
  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'cannot remove items from a non-draft invoice';
  end if;

  delete from public.global_invoice_items
  where id = p_invoice_item_id;

  perform public.recompute_global_invoice_totals(v_invoice.id);
end;
$function$;

GRANT ALL ON FUNCTION public.remove_global_invoice_item(bigint) TO anon;

GRANT ALL ON FUNCTION public.remove_global_invoice_item(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.remove_global_invoice_item(bigint) TO service_role;