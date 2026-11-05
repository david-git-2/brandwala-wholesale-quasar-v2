CREATE FUNCTION public.get_tenant_cash_in_report (
  p_tenant_id  bigint,
  p_start_date timestamp with time zone DEFAULT NULL::timestamp WITH time zone,
  p_end_date   timestamp with time zone DEFAULT NULL::timestamp WITH time zone
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_books_id bigint;
  v_cash_in numeric(18,4) := 0.0000;
  v_count integer := 0;
  v_by_method jsonb;
  v_entries jsonb;
begin
  if p_tenant_id is null then
    raise exception 'Tenant ID is required';
  end if;

  select coalesce(t.parent_id, t.id)
  into v_books_id
  from public.tenants t
  where t.id = p_tenant_id;

  if v_books_id is null then
    raise exception 'Tenant not found';
  end if;

  if not (
    public.membership_has_module_action(p_tenant_id, 'cashbook', 'view')
    or public.membership_has_module_action(v_books_id, 'cashbook', 'view')
  ) then
    raise exception 'Not authorized';
  end if;

  with receipt_invoice as (
    select
      ip.payment_id,
      min(ip.global_invoice_id) as invoice_id
    from public.pay_allocations ip
    group by ip.payment_id
  ),
  receipt_lines as (
    select
      gp.id as payment_id,
      gp.id::text || '-' || coalesce(gpi.id::text, 'h') as line_id,
      coalesce(gpi.amount, gp.amount) as amount,
      case
        when gp.collection_source = 'recipient'::public.collection_source_type then 'courier_remittance'
        else 'buyer_receipt'
      end as source_type,
      gp.id::text as source_id,
      nullif(trim(gp.note), '') as label,
      ri.invoice_id,
      gp.created_at,
      coalesce(gpi.payment_method_code, nullif(trim(gp.method::text), ''), 'other') as method,
      gpi.reference as instrument_reference,
      gpi.cheque_number,
      bb.name as bank_name
    from public.pays gp
    left join public.pay_instruments gpi on gpi.payment_id = gp.id
    left join public.bd_banks bb on bb.id = gpi.bd_bank_id
    left join receipt_invoice ri on ri.payment_id = gp.id
    where gp.tenant_id = v_books_id
      and gp.voided_at is null
      and coalesce(gp.method::text, '') <> 'wallet_credit'
      and (p_start_date is null or coalesce(gp.payment_date::timestamptz, gp.created_at) >= p_start_date)
      and (p_end_date is null or coalesce(gp.payment_date::timestamptz, gp.created_at) <= p_end_date)
  ),
  lined as (
    select distinct on (line_id)
      line_id as id,
      amount,
      source_type,
      source_id,
      case
        when bank_name is not null and cheque_number is not null then
          coalesce(label, '') || ' Cheque ' || cheque_number || ' @ ' || bank_name
        when instrument_reference is not null then coalesce(label, instrument_reference)
        else label
      end as label,
      invoice_id,
      created_at,
      method
    from receipt_lines
    order by line_id, amount desc
  )
  select
    coalesce(sum(amount), 0.0000),
    count(*)::integer,
    coalesce(
      (
        select jsonb_agg(jsonb_build_object(
          'method', m.method,
          'amount', m.amt,
          'count', m.cnt
        ) order by m.amt desc)
        from (
          select method, sum(amount) as amt, count(*)::integer as cnt
          from lined
          group by method
        ) m
      ),
      '[]'::jsonb
    ),
    coalesce(
      (
        select jsonb_agg(jsonb_build_object(
          'id', e.id,
          'amount', e.amount,
          'method', e.method,
          'source_type', e.source_type,
          'source_id', e.source_id,
          'label', e.label,
          'invoice_id', e.invoice_id,
          'created_at', e.created_at
        ) order by e.created_at desc, e.id desc)
        from lined e
      ),
      '[]'::jsonb
    )
  into v_cash_in, v_count, v_by_method, v_entries
  from lined;

  return jsonb_build_object(
    'tenant_id', v_books_id,
    'start_date', p_start_date,
    'end_date', p_end_date,
    'cash_in_total', v_cash_in,
    'entry_count', v_count,
    'by_method', v_by_method,
    'entries', v_entries
  );
end;
$function$;

GRANT ALL ON FUNCTION public.get_tenant_cash_in_report(bigint, timestamp WITH time zone, timestamp WITH time zone) TO anon;

GRANT ALL ON FUNCTION public.get_tenant_cash_in_report(bigint, timestamp WITH time zone, timestamp WITH time zone) TO authenticated;

GRANT ALL ON FUNCTION public.get_tenant_cash_in_report(bigint, timestamp WITH time zone, timestamp WITH time zone) TO service_role;