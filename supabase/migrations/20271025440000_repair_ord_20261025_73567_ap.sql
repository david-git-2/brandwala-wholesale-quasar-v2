-- One-off repair: ORD-20261025-73567 — close open courier AP debit note after pay-in.
do $$
declare
  v_order_id bigint;
  v_ap_bill_id bigint := 84;
  v_dn_bill_id bigint := 85;
  v_payment_id bigint := 23;
  v_dn_due numeric(12, 2);
  v_settlement_id bigint;
  v_order public.shop_orders;
begin
  select id into v_order_id
  from public.shop_orders
  where order_no = 'ORD-20261025-73567';

  if v_order_id is null then
    return;
  end if;

  select greatest(coalesce(due_amount, 0), 0)
  into v_dn_due
  from public.bills
  where id = v_dn_bill_id
    and parent_bill_id = v_ap_bill_id
  for update;

  if coalesce(v_dn_due, 0) > 0 then
    select * into v_order from public.shop_orders where id = v_order_id;

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
    select
      coalesce(b.issued_by_tenant_id, b.parent_tenant_id),
      b.parent_tenant_id,
      v_dn_bill_id,
      v_payment_id,
      v_dn_due,
      'dispute_settlement',
      format('Courier COD retention — order #%s — remittance %s (repair)', v_order_id, coalesce(v_order.courier_remittance_ref, '—')),
      null
    from public.bills b
    where b.id = v_dn_bill_id
      and not exists (
        select 1
        from public.invoice_write_offs iwo
        where iwo.invoice_id = v_dn_bill_id
          and iwo.reason = 'dispute_settlement'
          and coalesce(iwo.amount, 0) >= v_dn_due
      );

    perform public.recompute_global_invoice_payment_status(v_dn_bill_id);
    perform public.recompute_global_invoice_payment_status(v_ap_bill_id);
  end if;

  update public.shop_orders
  set cod_collect_amount = 9110.00
  where id = v_order_id
    and coalesce(cod_collect_amount, 0) = 0;

  select s.id into v_settlement_id
  from public.dropship_order_settlements s
  where s.shop_order_id = v_order_id;

  if v_settlement_id is not null then
    update public.dropship_order_settlements
    set
      remittance_at = coalesce(remittance_at, now()),
      status = 'confirmed'::public.dropship_settlement_status,
      updated_at = now()
    where id = v_settlement_id;
  end if;
end;
$$;
