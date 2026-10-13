-- Parent bill payment history includes pays on child credit/debit notes (e.g. vendor refunds).

CREATE OR REPLACE FUNCTION "public"."list_invoice_payment_history"("p_tenant_id" bigint, "p_invoice_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_result jsonb;
begin
  if p_tenant_id is null or p_invoice_id is null then
    raise exception 'Tenant and invoice are required.';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not exists (
    select 1
    from public.bills si
    where si.id = p_invoice_id
      and (si.parent_tenant_id = v_parent_id or si.issued_by_tenant_id = p_tenant_id)
  ) then
    raise exception 'Invoice not found for this tenant.';
  end if;

  select coalesce(jsonb_agg(row_to_json(r) order by r.sort_at desc, r.entry_id desc), '[]'::jsonb)
  into v_result
  from (
    select
      'allocation'::text as entry_type,
      ip.id as entry_id,
      gp.id as payment_id,
      gp.payment_date,
      gp.payment_date::timestamptz as sort_at,
      ip.amount as amount,
      gp.amount as receipt_amount,
      gp.voided_at,
      gp.method,
      gp.note,
      null::text as write_off_reason,
      coalesce(gp.settlement_currency_code, 'BDT') as settlement_currency_code,
      gp.foreign_amount,
      coalesce(gp.exchange_rate, 1.000000) as exchange_rate,
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', gpi.id,
              'payment_method_code', gpi.payment_method_code,
              'amount', gpi.amount,
              'reference', gpi.reference,
              'bd_bank_id', gpi.bd_bank_id,
              'bank_name', b.name,
              'cheque_number', gpi.cheque_number,
              'cheque_date', gpi.cheque_date,
              'sort_order', gpi.sort_order
            )
            order by gpi.sort_order, gpi.id
          )
          from public.pay_instruments gpi
          left join public.bd_banks b on b.id = gpi.bd_bank_id
          where gpi.payment_id = gp.id
        ),
        '[]'::jsonb
      ) as instruments,
      gp.source as payment_source,
      null::text as related_invoice_no,
      null::text as related_document_kind
    from public.pay_allocations ip
    join public.pays gp on gp.id = ip.payment_id
    where ip.global_invoice_id = p_invoice_id

    union all

    select
      'allocation'::text as entry_type,
      ip.id as entry_id,
      gp.id as payment_id,
      gp.payment_date,
      gp.payment_date::timestamptz as sort_at,
      ip.amount as amount,
      gp.amount as receipt_amount,
      gp.voided_at,
      gp.method,
      gp.note,
      null::text as write_off_reason,
      coalesce(gp.settlement_currency_code, 'BDT') as settlement_currency_code,
      gp.foreign_amount,
      coalesce(gp.exchange_rate, 1.000000) as exchange_rate,
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', gpi.id,
              'payment_method_code', gpi.payment_method_code,
              'amount', gpi.amount,
              'reference', gpi.reference,
              'bd_bank_id', gpi.bd_bank_id,
              'bank_name', b.name,
              'cheque_number', gpi.cheque_number,
              'cheque_date', gpi.cheque_date,
              'sort_order', gpi.sort_order
            )
            order by gpi.sort_order, gpi.id
          )
          from public.pay_instruments gpi
          left join public.bd_banks b on b.id = gpi.bd_bank_id
          where gpi.payment_id = gp.id
        ),
        '[]'::jsonb
      ) as instruments,
      gp.source as payment_source,
      child.invoice_no as related_invoice_no,
      child.document_kind::text as related_document_kind
    from public.pay_allocations ip
    join public.pays gp on gp.id = ip.payment_id
    join public.bills child on child.id = coalesce(ip.bill_id, ip.global_invoice_id)
    where child.parent_bill_id = p_invoice_id
      and child.document_kind in (
        'credit_note'::public.bill_document_kind,
        'debit_note'::public.bill_document_kind
      )

    union all

    select
      'write_off'::text as entry_type,
      iwo.id as entry_id,
      iwo.payment_id,
      coalesce(gp.payment_date, iwo.created_at::date) as payment_date,
      coalesce(gp.payment_date::timestamptz, iwo.created_at) as sort_at,
      iwo.amount as amount,
      coalesce(gp.amount, 0.00) as receipt_amount,
      gp.voided_at,
      coalesce(gp.method, 'write_off') as method,
      iwo.note,
      iwo.reason as write_off_reason,
      coalesce(gp.settlement_currency_code, 'BDT') as settlement_currency_code,
      gp.foreign_amount,
      coalesce(gp.exchange_rate, 1.000000) as exchange_rate,
      case
        when gp.id is null then '[]'::jsonb
        else coalesce(
          (
            select jsonb_agg(
              jsonb_build_object(
                'id', gpi.id,
                'payment_method_code', gpi.payment_method_code,
                'amount', gpi.amount,
                'reference', gpi.reference,
                'bd_bank_id', gpi.bd_bank_id,
                'bank_name', b.name,
                'cheque_number', gpi.cheque_number,
                'cheque_date', gpi.cheque_date,
                'sort_order', gpi.sort_order
              )
              order by gpi.sort_order, gpi.id
            )
            from public.pay_instruments gpi
            left join public.bd_banks b on b.id = gpi.bd_bank_id
            where gpi.payment_id = gp.id
          ),
          '[]'::jsonb
        )
      end as instruments,
      gp.source as payment_source,
      null::text as related_invoice_no,
      null::text as related_document_kind
    from public.invoice_write_offs iwo
    left join public.pays gp on gp.id = iwo.payment_id
    where iwo.invoice_id = p_invoice_id
  ) r;

  return v_result;
end;
$$;;
