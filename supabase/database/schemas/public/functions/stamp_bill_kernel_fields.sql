CREATE FUNCTION public.stamp_bill_kernel_fields (
  p_bill_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_bill public.bills;
  v_tenant_profile_id bigint;
  v_from bigint;
  v_to bigint;
  v_source_type text;
  v_source_id text;
  v_source_key text;
  v_settle public.bill_settlement_kind;
  v_kind text;
begin
  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.id is null then
    return;
  end if;

  select p.id into v_tenant_profile_id
  from public.profiles p
  where p.parent_tenant_id = v_bill.parent_tenant_id
    and p.profile_type = 'tenant'::public.profile_party_type
    and p.subject_id = v_bill.issued_by_tenant_id
  limit 1;

  if v_tenant_profile_id is null then
    select p.id into v_tenant_profile_id
    from public.profiles p
    where p.parent_tenant_id = v_bill.parent_tenant_id
      and p.profile_type = 'tenant'::public.profile_party_type
      and p.subject_id = v_bill.parent_tenant_id
    limit 1;
  end if;

  if v_bill.invoice_type = 'ap'::public.global_invoice_type then
    v_from := v_bill.profile_id;
    v_to := v_tenant_profile_id;
    v_source_type := coalesce(v_bill.source_type, 'shipment_cost');
    v_source_id := coalesce(v_bill.source_id, v_bill.ap_shipment_id::text);
    v_source_key := coalesce(v_bill.source_key, v_bill.ap_kind);
    v_settle := null;
  else
    v_from := v_tenant_profile_id;
    v_to := v_bill.profile_id;
    if v_bill.shop_order_id is not null then
      v_source_type := coalesce(v_bill.source_type, 'shop_order');
      v_source_id := coalesce(v_bill.source_id, v_bill.shop_order_id::text);
      v_source_key := v_bill.source_key;
    else
      v_source_type := coalesce(v_bill.source_type, 'compose');
      v_source_id := coalesce(v_bill.source_id, v_bill.id::text);
      v_source_key := v_bill.source_key;
    end if;
    v_kind := lower(trim(coalesce(v_bill.channel_meta->>'delivery_kind', '')));
    if v_bill.settlement_kind is not null then
      v_settle := v_bill.settlement_kind;
    elsif v_kind in ('take', 'condition') then
      v_settle := v_kind::public.bill_settlement_kind;
    else
      v_settle := 'take'::public.bill_settlement_kind;
    end if;
  end if;

  if v_from is not null and v_to is not null and v_from = v_to then
    v_to := v_bill.profile_id;
    if v_from = v_to then
      v_from := v_tenant_profile_id;
    end if;
  end if;

  -- Self-bills (counterparty is the tenant profile): keep one side, leave the other null.
  if v_from is not null and v_from = v_to then
    if v_bill.invoice_type = 'ap'::public.global_invoice_type then
      v_to := null;
    else
      v_from := null;
    end if;
  end if;

  update public.bills
  set
    from_profile_id = v_from,
    to_profile_id = v_to,
    source_type = v_source_type,
    source_id = v_source_id,
    source_key = v_source_key,
    settlement_kind = v_settle,
    currency_code = coalesce(nullif(trim(currency_code), ''), 'BDT')
  where id = p_bill_id;
end;
$function$;

GRANT ALL ON FUNCTION public.stamp_bill_kernel_fields(bigint) TO anon;

GRANT ALL ON FUNCTION public.stamp_bill_kernel_fields(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.stamp_bill_kernel_fields(bigint) TO service_role;