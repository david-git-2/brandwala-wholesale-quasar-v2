CREATE FUNCTION public.resolve_dropship_courier_ap_bill_id (
  p_order_id         bigint,
  p_parent_tenant_id bigint
)
  RETURNS bigint
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select b.id
  from public.bills b
  where b.parent_tenant_id = p_parent_tenant_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and (
      (b.source_type = 'dropship_courier' and b.source_id = p_order_id::text)
      or (
        b.source_type = 'shop_order'
        and b.source_id = p_order_id::text
        and coalesce(b.source_key, '') = 'courier'
      )
    )
    and b.invoice_status <> 'voided'::public.global_invoice_status
  order by b.id
  limit 1;
$function$;

GRANT ALL ON FUNCTION public.resolve_dropship_courier_ap_bill_id(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.resolve_dropship_courier_ap_bill_id(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.resolve_dropship_courier_ap_bill_id(bigint, bigint) TO service_role;