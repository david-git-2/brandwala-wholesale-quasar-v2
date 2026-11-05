CREATE FUNCTION public.settle_dropship_courier_ap_via_cod_retention (
  p_ap_bill_id         bigint,
  p_amount             numeric,
  p_order_id           bigint,
  p_remittance_ref     text,
  p_receipt_payment_id bigint  DEFAULT NULL::bigint
)
  RETURNS numeric
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ap public.bills;
  v_bal jsonb;
  v_family_due numeric(12, 2);
  v_remaining numeric(12, 2);
  v_chunk numeric(12, 2);
  v_total_settled numeric(12, 2) := 0;
  v_bill record;
  v_operating_tenant_id bigint;
  v_note text;
begin
  if p_ap_bill_id is null then
    return 0;
  end if;

  select * into v_ap from public.bills where id = p_ap_bill_id for update;
  if v_ap.id is null then
    raise exception 'courier AP bill not found';
  end if;

  if v_ap.invoice_type <> 'ap'::public.global_invoice_type then
    raise exception 'bill is not an AP bill';
  end if;

  if v_ap.invoice_status <> 'issued'::public.global_invoice_status then
    return 0;
  end if;

  v_bal := public.get_bill_net_balances(p_ap_bill_id);
  v_family_due := greatest(coalesce((v_bal->>'due_amount')::numeric, 0), 0);
  v_remaining := least(
    round(greatest(coalesce(p_amount, 0), 0), 2),
    v_family_due
  );

  if v_remaining <= 0 then
    return 0;
  end if;

  v_note := format(
    'Courier COD retention — order #%s — remittance %s',
    p_order_id,
    coalesce(nullif(trim(p_remittance_ref), ''), '—')
  );

  for v_bill in
    select
      b.id,
      b.due_amount,
      b.issued_by_tenant_id,
      b.parent_tenant_id
    from public.bills b
    where (
        b.id = p_ap_bill_id
        or b.parent_bill_id = p_ap_bill_id
      )
      and b.invoice_status = 'issued'::public.global_invoice_status
      and greatest(coalesce(b.due_amount, 0), 0) > 0
    order by
      case when b.id = p_ap_bill_id then 0 else 1 end,
      b.id
    for update
  loop
    v_chunk := least(v_remaining, greatest(coalesce(v_bill.due_amount, 0), 0));
    if v_chunk <= 0 then
      continue;
    end if;

    v_operating_tenant_id := coalesce(v_bill.issued_by_tenant_id, v_bill.parent_tenant_id);

    insert into public.invoice_write_offs (
      tenant_id,
      parent_tenant_id,
      invoice_id,
      payment_id,
      amount,
      reason,
      note,
      approved_by
    )
    values (
      v_operating_tenant_id,
      v_bill.parent_tenant_id,
      v_bill.id,
      p_receipt_payment_id,
      v_chunk,
      'dispute_settlement',
      v_note,
      auth.uid()
    );

    perform public.recompute_global_invoice_payment_status(v_bill.id);

    v_total_settled := v_total_settled + v_chunk;
    v_remaining := v_remaining - v_chunk;

    if v_remaining <= 0 then
      exit;
    end if;
  end loop;

  perform public.recompute_global_invoice_payment_status(p_ap_bill_id);

  return round(v_total_settled, 2);
end;
$function$;

GRANT ALL ON FUNCTION public.settle_dropship_courier_ap_via_cod_retention(bigint, numeric, bigint, text, bigint) TO anon;

GRANT ALL ON FUNCTION public.settle_dropship_courier_ap_via_cod_retention(bigint, numeric, bigint, text, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.settle_dropship_courier_ap_via_cod_retention(bigint, numeric, bigint, text, bigint) TO service_role;