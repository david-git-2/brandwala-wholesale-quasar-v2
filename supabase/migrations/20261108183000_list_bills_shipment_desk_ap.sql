-- Shipment gear: include desk-issued AP bills (ap_shipment_id) in list_bills_for_source
-- when ap_shipment_buckets_only, and backfill plug fields on linked AP bills.

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

  if not (
    public.user_can_manage_books_tenant(v_parent_id)
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

CREATE OR REPLACE FUNCTION public.issue_ap_bill_from_desk(p_bill_id bigint)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_result public.bills;
begin
  select * into v_bill from public.bills where id = p_bill_id for update;
  if v_bill.id is null then
    raise exception 'bill not found';
  end if;

  if v_bill.invoice_type is distinct from 'ap'::public.global_invoice_type then
    raise exception 'Only AP bills can be issued from the bills desk';
  end if;

  if v_bill.document_kind is distinct from 'standard'::public.bill_document_kind then
    raise exception 'Only standard AP bills can be issued from the bills desk';
  end if;

  if v_bill.invoice_status is distinct from 'draft'::public.global_invoice_status then
    raise exception 'Only draft AP bills can be issued from the bills desk';
  end if;

  if coalesce(v_bill.total_amount, 0) <= 0 then
    raise exception 'Bill total must be greater than zero';
  end if;

  if not public.user_can_manage_books_tenant(v_bill.tenant_id) then
    raise exception 'Permission denied';
  end if;

  perform set_config('app.bill_desk_issue_shipment_ap', '1', true);
  perform set_config('app.shipment_ap_issue', '1', true);
  begin
    v_result := public.issue_bill(p_bill_id);
  exception
    when others then
      perform set_config('app.bill_desk_issue_shipment_ap', '0', true);
      perform set_config('app.shipment_ap_issue', '0', true);
      raise;
  end;
  perform set_config('app.bill_desk_issue_shipment_ap', '0', true);
  perform set_config('app.shipment_ap_issue', '0', true);

  if v_result.ap_shipment_id is not null then
    update public.bills b
    set
      source_type = coalesce(nullif(btrim(b.source_type), ''), 'shipment_cost'),
      source_id = coalesce(nullif(btrim(b.source_id), ''), b.ap_shipment_id::text),
      ap_kind = coalesce(
        nullif(btrim(b.ap_kind), ''),
        nullif(btrim(b.channel_meta->>'ap_kind'), ''),
        case
          when split_part(coalesce(b.source_key, ''), ':', 1) in (
            'material', 'freight', 'customs', 'handling', 'finance', 'other',
            'vendor', 'cargo', 'local'
          ) then split_part(b.source_key, ':', 1)
          else null
        end
      ),
      updated_at = now()
    where b.id = p_bill_id;

    select * into v_result from public.bills where id = p_bill_id;
    perform public.stamp_bill_kernel_fields(p_bill_id);
  end if;

  return v_result;
end;
$$;

UPDATE public.bills b
SET
  source_type = coalesce(nullif(btrim(b.source_type), ''), 'shipment_cost'),
  source_id = coalesce(nullif(btrim(b.source_id), ''), b.ap_shipment_id::text),
  ap_kind = coalesce(
    nullif(btrim(b.ap_kind), ''),
    nullif(btrim(b.channel_meta->>'ap_kind'), ''),
    case
      when split_part(coalesce(b.source_key, ''), ':', 1) in (
        'material', 'freight', 'customs', 'handling', 'finance', 'other',
        'vendor', 'cargo', 'local'
      ) then split_part(b.source_key, ':', 1)
      else null
    end
  ),
  updated_at = now()
WHERE b.invoice_type = 'ap'::public.global_invoice_type
  AND b.document_kind = 'standard'::public.bill_document_kind
  AND b.ap_shipment_id IS NOT NULL
  AND b.invoice_status <> 'voided'::public.global_invoice_status
  AND (
    nullif(btrim(b.source_type), '') IS DISTINCT FROM 'shipment_cost'
    OR nullif(btrim(b.source_id), '') IS DISTINCT FROM b.ap_shipment_id::text
    OR nullif(btrim(b.ap_kind), '') IS NULL
  );
