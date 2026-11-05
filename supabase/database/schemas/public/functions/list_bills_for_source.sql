CREATE FUNCTION public.list_bills_for_source (
  p_parent_tenant_id         bigint,
  p_source_type              text,
  p_source_id                text,
  p_source_key               text    DEFAULT NULL::text,
  p_include_voided           boolean DEFAULT false,
  p_ap_shipment_buckets_only boolean DEFAULT false
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent_id bigint;
  v_sid bigint;
  v_rows jsonb;
begin
  if p_parent_tenant_id is null then
    raise exception 'parent_tenant_id is required';
  end if;
  if nullif(trim(coalesce(p_source_type, '')), '') is null then
    raise exception 'source_type is required';
  end if;
  if nullif(trim(coalesce(p_source_id, '')), '') is null then
    raise exception 'source_id is required';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_parent_tenant_id);

  if not (
    public.user_can_manage_parent_tenant(v_parent_id)
    or public.membership_has_module_action(v_parent_id, 'global_invoice', 'view')
  ) then
    raise exception 'not allowed';
  end if;

  v_sid := nullif(trim(p_source_id), '')::bigint;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', b.id,
        'invoice_no', b.invoice_no,
        'invoice_type', b.invoice_type,
        'document_kind', b.document_kind,
        'ap_kind', b.ap_kind,
        'source_type', b.source_type,
        'source_id', b.source_id,
        'source_key', b.source_key,
        'invoice_status', b.invoice_status,
        'payment_status', b.payment_status,
        'total_amount', b.total_amount,
        'due_amount', b.due_amount,
        'parent_bill_id', b.parent_bill_id,
        'net_balances', public.get_bill_net_balances(b.id)
      )
      ORDER BY b.id
    ),
    '[]'::jsonb
  )
  into v_rows
  from public.bills b
  where b.parent_tenant_id = v_parent_id
    and (p_include_voided or b.invoice_status <> 'voided'::public.global_invoice_status)
    and (
      (b.source_type = p_source_type and b.source_id = p_source_id)
      or (
        p_source_type = 'shipment_cost'
        and b.invoice_type = 'ap'::public.global_invoice_type
        and b.document_kind = 'standard'::public.bill_document_kind
        and (
          (b.source_type = 'shipment_cost' and b.source_id = p_source_id)
          or (v_sid is not null and b.ap_shipment_id = v_sid)
        )
      )
      or (
        p_source_type = 'shop_order'
        and b.source_type = 'shop_order'
        and b.source_id = p_source_id
      )
      or (
        p_source_type = 'shop_order'
        and b.source_type = 'delivery_close'
        and (
          (
            coalesce(b.channel_meta->>'document_type', '') = 'shop_order'
            and coalesce(b.channel_meta->>'document_id', '') = p_source_id
          )
          or exists (
            select 1
            from public.delivery_paper dp
            where dp.id::text = b.source_id
              and dp.source_type = 'shop_order'::public.delivery_paper_source_type
              and dp.source_id::text = p_source_id
          )
        )
      )
    )
    and (p_source_key is null or b.source_key = p_source_key)
    and (
      not p_ap_shipment_buckets_only
      or coalesce(b.source_key, b.ap_kind) in (
        'material', 'freight', 'customs', 'handling', 'finance', 'other',
        'vendor', 'cargo', 'local'
      )
      or coalesce(b.source_key, '') ~ '^(material|freight|customs|handling|finance|other|vendor|cargo|local):'
    );

  return v_rows;
end;
$function$;

GRANT ALL ON FUNCTION public.list_bills_for_source(bigint, text, text, text, boolean, boolean) TO anon;

GRANT ALL ON FUNCTION public.list_bills_for_source(bigint, text, text, text, boolean, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.list_bills_for_source(bigint, text, text, text, boolean, boolean) TO service_role;