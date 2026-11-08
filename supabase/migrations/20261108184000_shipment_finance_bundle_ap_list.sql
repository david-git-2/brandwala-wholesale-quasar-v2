-- Shipment gear finance bundle: load AP bills without nested list_bills_for_source
-- books-only permission (procurement members could open costs but see "Not synced").
-- Also allow shipment members on list_bills_for_source for shipment_cost.

CREATE OR REPLACE FUNCTION public._list_shipment_cost_ap_bills_json(
  p_books_tenant_id bigint,
  p_shipment_id bigint,
  p_include_voided boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', b.id,
        'invoice_no', b.invoice_no,
        'invoice_type', b.invoice_type,
        'document_kind', b.document_kind,
        'ap_kind', coalesce(
          nullif(btrim(b.ap_kind), ''),
          nullif(btrim(b.channel_meta->>'ap_kind'), ''),
          nullif(split_part(coalesce(b.source_key, ''), ':', 1), '')
        ),
        'ap_shipment_id', b.ap_shipment_id,
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
      order by b.id
    ),
    '[]'::jsonb
  )
  from public.bills b
  where b.tenant_id = p_books_tenant_id
    and (p_include_voided or b.invoice_status <> 'voided'::public.global_invoice_status)
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and (
      (b.source_type = 'shipment_cost' and b.source_id = p_shipment_id::text)
      or b.ap_shipment_id = p_shipment_id
    )
    and (
      b.ap_shipment_id = p_shipment_id
      or coalesce(
        nullif(btrim(b.ap_kind), ''),
        nullif(btrim(b.channel_meta->>'ap_kind'), ''),
        nullif(btrim(b.source_key), ''),
        split_part(coalesce(b.source_key, ''), ':', 1)
      ) in (
        'material', 'freight', 'customs', 'handling', 'finance', 'other',
        'vendor', 'cargo', 'local'
      )
      or coalesce(b.source_key, '') ~ '^(material|freight|customs|handling|finance|other|vendor|cargo|local):'
    );
$$;

CREATE OR REPLACE FUNCTION public.get_shipment_settings_finance_bundle(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent bigint;
  v_cost_entries jsonb;
  v_ap_bills jsonb;
  v_ap_fx jsonb;
  v_sid text;
  v_elem jsonb;
  v_slim jsonb := '[]'::jsonb;
begin
  select gs.tenant_id into v_parent
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if v_parent is null then
    raise exception 'shipment not found';
  end if;

  if not (
    public.user_can_manage_books_tenant(v_parent)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_parent
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  ) then
    raise exception 'not allowed';
  end if;

  perform public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);
  perform public.sync_shipment_ap_bills(p_shipment_id);

  v_sid := p_shipment_id::text;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ce.id,
        'shipment_id', ce.shipment_id,
        'cost_bucket', ce.cost_bucket,
        'cost_component', ce.cost_component,
        'is_capitalizable', ce.is_capitalizable,
        'description', ce.description,
        'amount', ce.amount,
        'currency_id', ce.currency_id,
        'metadata', ce.metadata,
        'section_id', ce.section_id
      )
      order by ce.cost_bucket, ce.cost_component, ce.id
    ),
    '[]'::jsonb
  )
  into v_cost_entries
  from public.global_shipment_cost_entries ce
  where ce.shipment_id = p_shipment_id;

  for v_elem in
    select value
    from jsonb_array_elements(
      public._list_shipment_cost_ap_bills_json(v_parent, p_shipment_id, false)
    )
  loop
    v_slim := v_slim || jsonb_build_array(
      jsonb_build_object(
        'id', v_elem->'id',
        'invoice_no', v_elem->'invoice_no',
        'ap_kind', v_elem->'ap_kind',
        'source_type', v_elem->'source_type',
        'source_id', v_elem->'source_id',
        'source_key', v_elem->'source_key',
        'invoice_status', v_elem->'invoice_status',
        'payment_status', v_elem->'payment_status',
        'total_amount', v_elem->'total_amount',
        'due_amount', coalesce(
          v_elem->'net_balances'->'open_books',
          v_elem->'due_amount'
        )
      )
    );
  end loop;
  v_ap_bills := v_slim;

  v_ap_fx := public._global_shipment_landed_fx_inputs(p_shipment_id);
  v_ap_fx := v_ap_fx - 'blended_rate';

  return jsonb_build_object(
    'cost_entries', v_cost_entries,
    'ap_bills', v_ap_bills,
    'ap_fx', v_ap_fx
  );
end;
$$;

-- list_bills_for_source: shipment_cost + active membership (matches shipment gear access)
CREATE OR REPLACE FUNCTION public.list_bills_for_source(
  p_tenant_id bigint,
  p_source_type text,
  p_source_id text,
  p_source_key text DEFAULT NULL,
  p_include_voided boolean DEFAULT false,
  p_ap_shipment_buckets_only boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent_id bigint;
  v_sid bigint;
  v_rows jsonb;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;
  if nullif(trim(coalesce(p_source_type, '')), '') is null then
    raise exception 'source_type is required';
  end if;
  if nullif(trim(coalesce(p_source_id, '')), '') is null then
    raise exception 'source_id is required';
  end if;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);
  v_sid := nullif(trim(p_source_id), '')::bigint;

  if not (
    public.user_can_manage_books_tenant(v_parent_id)
    or public.membership_has_module_action(v_parent_id, 'global_invoice', 'view')
    or (
      p_source_type = 'shipment_cost'
      and v_sid is not null
      and exists (
        select 1
        from public.global_shipments gs
        where gs.id = v_sid
          and public.resolve_books_tenant_id(gs.tenant_id) = v_parent_id
      )
      and exists (
        select 1
        from public.memberships m
        where m.tenant_id = v_parent_id
          and lower(trim(m.email)) = public.current_user_email()
          and m.is_active = true
      )
    )
  ) then
    raise exception 'not allowed';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', b.id,
        'invoice_no', b.invoice_no,
        'invoice_type', b.invoice_type,
        'document_kind', b.document_kind,
        'ap_kind', coalesce(
          nullif(btrim(b.ap_kind), ''),
          nullif(btrim(b.channel_meta->>'ap_kind'), ''),
          nullif(split_part(coalesce(b.source_key, ''), ':', 1), '')
        ),
        'ap_shipment_id', b.ap_shipment_id,
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
  where b.tenant_id = v_parent_id
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
      or (
        p_source_type = 'shipment_cost'
        and v_sid is not null
        and b.invoice_type = 'ap'::public.global_invoice_type
        and b.document_kind = 'standard'::public.bill_document_kind
        and b.ap_shipment_id = v_sid
      )
      or coalesce(
        nullif(btrim(b.ap_kind), ''),
        nullif(btrim(b.channel_meta->>'ap_kind'), ''),
        nullif(btrim(b.source_key), ''),
        split_part(coalesce(b.source_key, ''), ':', 1)
      ) in (
        'material', 'freight', 'customs', 'handling', 'finance', 'other',
        'vendor', 'cargo', 'local'
      )
      or coalesce(b.source_key, '') ~ '^(material|freight|customs|handling|finance|other|vendor|cargo|local):'
    );

  return v_rows;
end;
$$;
