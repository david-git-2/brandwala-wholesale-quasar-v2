CREATE FUNCTION public.sync_invoice_from_preorder_demand_document (
  p_tenant_id     bigint,
  p_document_type text,
  p_document_id   bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_operating_tenant_id bigint;
  v_invoice_id bigint;
  v_doc_status text;
  v_invoice_status public.global_invoice_status;
  v_items jsonb := '[]'::jsonb;
  v_remove_ids jsonb := '[]'::jsonb;
  v_payload jsonb;
  v_result jsonb;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;

  if v_doc_type = 'shop_order' then
    select
      o.tenant_id,
      o.global_invoice_id,
      public.normalize_shop_order_procurement_status(o.status)
    into v_operating_tenant_id, v_invoice_id, v_doc_status
    from public.shop_orders o
    where o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog';

    if v_operating_tenant_id is null then
      raise exception 'shop order not found or not vendor_catalog';
    end if;
  elsif v_doc_type = 'pbc_costing_file' then
    select
      f.tenant_id,
      f.invoice_id,
      public.normalize_pbc_procurement_status(f.status)
    into v_operating_tenant_id, v_invoice_id, v_doc_status
    from public.product_based_costing_files f
    where f.id = p_document_id;

    if v_operating_tenant_id is null then
      raise exception 'costing file not found';
    end if;
  else
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  if not public.can_access_preorder_demand_tenant(p_tenant_id)
    and not public.can_access_preorder_demand_tenant(v_operating_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_doc_status <> 'packed' then
    raise exception 'document must be packed to sync invoice from demand';
  end if;

  if v_invoice_id is null then
    raise exception 'document has no linked invoice';
  end if;

  select si.invoice_status
  into v_invoice_status
  from public.bills si
  where si.id = v_invoice_id;

  if v_invoice_status is null then
    raise exception 'invoice not found';
  end if;

  if v_invoice_status not in (
    'draft'::public.global_invoice_status,
    'proforma_generated'::public.global_invoice_status
  ) then
    raise exception 'invoice is not editable (status: %)', v_invoice_status;
  end if;

  v_items := public.build_preorder_demand_invoice_items(v_doc_type, p_document_id);

  if jsonb_array_length(v_items) = 0 then
    raise exception 'at least one stock pick is required to sync invoice';
  end if;

  select coalesce(jsonb_agg(sii.id), '[]'::jsonb)
  into v_remove_ids
  from public.bill_lines sii
  where sii.invoice_id = v_invoice_id;

  v_payload := jsonb_build_object(
    'items', v_items,
    'remove_item_ids', v_remove_ids
  );

  v_result := public.update_sales_invoice_from_payload(
    coalesce(v_operating_tenant_id, p_tenant_id),
    v_invoice_id,
    v_payload
  );

  if coalesce(v_result->>'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_result->>'error', 'failed to sync invoice from demand');
  end if;

  return v_result || jsonb_build_object(
    'invoice_id', v_invoice_id,
    'synced', true
  );
end;
$function$;

GRANT ALL ON FUNCTION public.sync_invoice_from_preorder_demand_document(bigint, text, bigint) TO anon;

GRANT ALL ON FUNCTION public.sync_invoice_from_preorder_demand_document(bigint, text, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.sync_invoice_from_preorder_demand_document(bigint, text, bigint) TO service_role;