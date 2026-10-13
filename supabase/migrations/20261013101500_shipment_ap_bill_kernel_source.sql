-- Shipment AP bills: kernel source plug (shipment_cost) + stamp on sync upsert

UPDATE public.bills
SET
  source_type = coalesce(source_type, 'shipment_cost'),
  source_id = coalesce(source_id, ap_shipment_id::text),
  source_key = coalesce(source_key, ap_kind)
WHERE invoice_type = 'ap'::public.global_invoice_type
  AND ap_shipment_id IS NOT NULL
  AND document_kind = 'standard'::public.bill_document_kind
  AND (source_type IS NULL OR source_id IS NULL OR source_key IS NULL);

CREATE OR REPLACE FUNCTION "public"."_upsert_shipment_ap_bill"("p_parent_tenant_id" bigint, "p_issued_by_tenant_id" bigint, "p_shipment_id" bigint, "p_shipment_name" "text", "p_ap_kind" "text", "p_profile_id" bigint, "p_amount" numeric, "p_ap_paper" "jsonb" DEFAULT NULL::"jsonb", "p_keep_as_draft" boolean DEFAULT false) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_bill public.bills;
  v_target numeric(12, 2);
  v_due numeric(12, 2);
  v_status text;
  v_invoice_no text;
  v_kind_label text;
  v_meta_base jsonb;
  v_paper_status public.global_invoice_status;
begin
  if p_ap_kind not in (
    'vendor', 'cargo', 'local',
    'material', 'freight', 'customs', 'handling', 'finance', 'other'
  ) then
    raise exception 'Invalid ap_kind %', p_ap_kind;
  end if;

  select * into v_bill
  from public.bills b
  where b.parent_tenant_id = p_parent_tenant_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and (
      (
        b.source_type = 'shipment_cost'
        and b.source_id = p_shipment_id::text
        and b.source_key = p_ap_kind
      )
      or (b.ap_shipment_id = p_shipment_id and b.ap_kind = p_ap_kind)
    )
  for update;

  if p_profile_id is null or coalesce(p_amount, 0) <= 0 then
    if v_bill.id is not null and coalesce(v_bill.paid_amount, 0) = 0
       and v_bill.invoice_status in (
         'issued'::public.global_invoice_status,
         'draft'::public.global_invoice_status
       ) then
      update public.bills
      set invoice_status = 'voided'::public.global_invoice_status, updated_at = now()
      where id = v_bill.id;
    end if;
    return null;
  end if;

  v_target := round(p_amount, 2);
  v_kind_label := initcap(replace(p_ap_kind, '_', ' '));
  v_meta_base := jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id);
  if p_ap_paper is not null then
    v_meta_base := v_meta_base || jsonb_build_object('ap_paper', p_ap_paper);
  end if;

  v_paper_status := case
    when p_keep_as_draft then 'draft'::public.global_invoice_status
    else 'issued'::public.global_invoice_status
  end;

  if v_bill.id is null then
    v_invoice_no := public.generate_sales_invoice_number(p_issued_by_tenant_id, 'ap'::public.global_invoice_type, current_date);
    insert into public.bills (
      parent_tenant_id, issued_by_tenant_id, invoice_no, invoice_type, invoice_date,
      invoice_status, profile_id, collection_source, payment_status,
      subtotal_amount, total_amount, due_amount, paid_amount,
      ap_shipment_id, ap_kind, source_type, source_id, source_key, currency_code,
      note, channel_meta, document_kind
    ) values (
      p_parent_tenant_id, p_issued_by_tenant_id, v_invoice_no, 'ap'::public.global_invoice_type, current_date,
      v_paper_status, p_profile_id, 'profile'::public.collection_source_type, 'due',
      v_target, v_target, v_target, 0,
      p_shipment_id, p_ap_kind, 'shipment_cost', p_shipment_id::text, p_ap_kind, 'BDT',
      format('Shipment %s — %s AP', coalesce(p_shipment_name, p_shipment_id::text), v_kind_label),
      v_meta_base,
      'standard'::public.bill_document_kind
    )
    returning id into v_bill.id;
    perform public.stamp_bill_kernel_fields(v_bill.id);
    return v_bill.id;
  end if;

  if v_bill.invoice_status = 'voided'::public.global_invoice_status then
    if coalesce(v_bill.paid_amount, 0) > 0 then
      return v_bill.id;
    end if;

    update public.bills
    set
      invoice_status = v_paper_status,
      profile_id = p_profile_id,
      subtotal_amount = v_target,
      total_amount = v_target,
      due_amount = v_target,
      payment_status = 'due',
      source_type = coalesce(source_type, 'shipment_cost'),
      source_id = coalesce(source_id, p_shipment_id::text),
      source_key = coalesce(source_key, p_ap_kind),
      currency_code = coalesce(nullif(trim(currency_code), ''), 'BDT'),
      note = format('Shipment %s — %s AP', coalesce(p_shipment_name, p_shipment_id::text), v_kind_label),
      channel_meta = coalesce(channel_meta, '{}'::jsonb)
        || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
        || case
          when p_ap_paper is not null then jsonb_build_object('ap_paper', p_ap_paper)
          else '{}'::jsonb
        end,
      updated_at = now()
    where id = v_bill.id;

    perform public.stamp_bill_kernel_fields(v_bill.id);
    return v_bill.id;
  end if;

  v_target := greatest(v_target, coalesce(v_bill.paid_amount, 0));
  v_due := greatest(v_target - coalesce(v_bill.paid_amount, 0), 0);
  v_status := case
    when v_due <= 0 then 'paid'
    when coalesce(v_bill.paid_amount, 0) > 0 then 'partially_paid'
    else 'due'
  end;

  update public.bills
  set
    profile_id = p_profile_id,
    subtotal_amount = v_target,
    total_amount = v_target,
    due_amount = v_due,
    payment_status = v_status,
    source_type = coalesce(source_type, 'shipment_cost'),
    source_id = coalesce(source_id, p_shipment_id::text),
    source_key = coalesce(source_key, p_ap_kind),
    currency_code = coalesce(nullif(trim(currency_code), ''), 'BDT'),
    note = format('Shipment %s — %s AP', coalesce(p_shipment_name, p_shipment_id::text), v_kind_label),
    channel_meta = coalesce(channel_meta, '{}'::jsonb)
      || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
      || case
        when p_ap_paper is not null and coalesce(v_bill.paid_amount, 0) = 0
        then jsonb_build_object('ap_paper', p_ap_paper)
        else '{}'::jsonb
      end,
    updated_at = now()
  where id = v_bill.id;

  perform public.stamp_bill_kernel_fields(v_bill.id);
  return v_bill.id;
end;
$$;

ALTER FUNCTION "public"."_upsert_shipment_ap_bill"("p_parent_tenant_id" bigint, "p_issued_by_tenant_id" bigint, "p_shipment_id" bigint, "p_shipment_name" "text", "p_ap_kind" "text", "p_profile_id" bigint, "p_amount" numeric, "p_ap_paper" "jsonb", "p_keep_as_draft" boolean) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."issue_shipment_ap_bills"("p_shipment_id" bigint) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent bigint;
  v_count integer := 0;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select gs.parent_tenant_id into v_parent
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if v_parent is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent)
  ) then
    raise exception 'Permission denied';
  end if;

  update public.bills b
  set invoice_status = 'issued'::public.global_invoice_status, updated_at = now()
  where b.parent_tenant_id = v_parent
    and b.ap_shipment_id = p_shipment_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and b.invoice_status = 'draft'::public.global_invoice_status
    and coalesce(b.total_amount, 0) > 0;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;


ALTER FUNCTION "public"."issue_shipment_ap_bills"("p_shipment_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."issue_shipment_ap_bill_for_kind"("p_shipment_id" bigint, "p_ap_kind" "text") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent bigint;
  v_bill_id bigint;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  if p_ap_kind is null or trim(p_ap_kind) = '' then
    raise exception 'ap_kind is required';
  end if;

  if p_ap_kind not in (
    'vendor', 'cargo', 'local',
    'material', 'freight', 'customs', 'handling', 'finance', 'other'
  ) then
    raise exception 'Invalid ap_kind %', p_ap_kind;
  end if;

  select gs.parent_tenant_id into v_parent
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if v_parent is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent)
  ) then
    raise exception 'Permission denied';
  end if;

  update public.bills b
  set
    invoice_status = 'issued'::public.global_invoice_status,
    payment_status = coalesce(nullif(b.payment_status, ''), 'due'),
    source_type = coalesce(b.source_type, 'shipment_cost'),
    source_id = coalesce(b.source_id, p_shipment_id::text),
    source_key = coalesce(b.source_key, p_ap_kind),
    updated_at = now()
  where b.parent_tenant_id = v_parent
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and b.invoice_status = 'draft'::public.global_invoice_status
    and coalesce(b.total_amount, 0) > 0
    and (
      (
        b.source_type = 'shipment_cost'
        and b.source_id = p_shipment_id::text
        and b.source_key = p_ap_kind
      )
      or (b.ap_shipment_id = p_shipment_id and b.ap_kind = p_ap_kind)
    )
  returning b.id into v_bill_id;

  if v_bill_id is null then
    raise exception 'No draft AP bill to issue for bucket %', p_ap_kind;
  end if;

  return v_bill_id;
end;
$$;
