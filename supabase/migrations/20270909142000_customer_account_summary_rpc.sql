-- Customer account summary for staff drawer + parent-books billing profile fallback

begin;

create or replace function public.resolve_billing_profile_for_customer_group(
  p_tenant_id bigint,
  p_customer_group_id bigint
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_billing_profile_id bigint;
  v_books_id bigint;
begin
  if p_customer_group_id is null then
    return null;
  end if;

  select id into v_billing_profile_id
  from public.billing_profiles
  where tenant_id = p_tenant_id
    and customer_group_id = p_customer_group_id
  order by id
  limit 1;

  if v_billing_profile_id is not null then
    return v_billing_profile_id;
  end if;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  select id into v_billing_profile_id
  from public.billing_profiles bp
  where bp.customer_group_id = p_customer_group_id
    and (
      bp.tenant_id = v_books_id
      or bp.tenant_id in (
        select t.id from public.tenants t where t.parent_id = v_books_id
      )
    )
  order by
    case
      when bp.tenant_id = p_tenant_id then 0
      when bp.tenant_id = v_books_id then 1
      else 2
    end,
    bp.id
  limit 1;

  return v_billing_profile_id;
end;
$$;

create or replace function public.get_customer_account_summary_for_staff(
  p_tenant_id bigint,
  p_customer_group_id bigint
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_books_id bigint;
  v_group_tenant_id bigint;
  v_billing_profile_id bigint;
  v_bp_ids bigint[];
  v_still_due numeric(12, 2) := 0;
  v_total_billed numeric(12, 2) := 0;
  v_settlement numeric(12, 2) := 0;
  v_collected_cash numeric(12, 2) := 0;
  v_wallet_applied numeric(12, 2) := 0;
  v_store_credit numeric(15, 4) := 0;
  v_unallocated numeric(12, 2) := 0;
  v_open_invoices jsonb := '[]'::jsonb;
  v_recent_payments jsonb := '[]'::jsonb;
  v_recent_ledger jsonb := '[]'::jsonb;
  v_shop_access jsonb := '[]'::jsonb;
begin
  if p_tenant_id is null or p_customer_group_id is null then
    return jsonb_build_object('success', false, 'error', 'tenant and customer group are required');
  end if;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not (
    public.is_tenant_staff(p_tenant_id)
    or public.membership_has_module_action(v_books_id, 'customer', 'view')
  ) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  select cg.tenant_id
  into v_group_tenant_id
  from public.customer_groups cg
  where cg.id = p_customer_group_id;

  if v_group_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'customer group not found');
  end if;

  select
    coalesce(array_agg(bp.id order by
      case when bp.tenant_id = v_group_tenant_id then 0 else 1 end,
      bp.id
    ), '{}'::bigint[]),
    (array_agg(bp.id order by
      case when bp.tenant_id = v_group_tenant_id then 0 else 1 end,
      bp.id
    ))[1]
  into v_bp_ids, v_billing_profile_id
  from public.billing_profiles bp
  where bp.customer_group_id = p_customer_group_id
    and (
      bp.tenant_id = v_books_id
      or bp.tenant_id in (
        select t.id from public.tenants t where t.parent_id = v_books_id
      )
    );

  if v_billing_profile_id is null then
    return jsonb_build_object(
      'success', true,
      'books_tenant_id', v_books_id,
      'billing_profile_id', null,
      'still_due', 0,
      'total_billed', 0,
      'collected_cash', 0,
      'wallet_applied', 0,
      'settlement', 0,
      'store_credit_balance', 0,
      'unallocated_payments', 0,
      'open_invoices', '[]'::jsonb,
      'recent_payments', '[]'::jsonb,
      'recent_ledger', '[]'::jsonb,
      'shop_access', coalesce((
        select jsonb_agg(to_jsonb(r))
        from (
          select
            s.id as shop_id,
            s.name as shop_name,
            s.shop_type::text as shop_type,
            st.id as shop_tenant_id,
            st.name as shop_tenant_name,
            scga.status,
            scga.credit_limit_amount
          from public.shop_customer_group_access scga
          join public.shops s on s.id = scga.shop_id
          join public.tenants st on st.id = s.tenant_id
          where scga.customer_group_id = p_customer_group_id
          order by st.name, s.name
          limit 20
        ) r
      ), '[]'::jsonb)
    );
  end if;

  select
    coalesce(sum(si.due_amount), 0.00),
    coalesce(sum(si.total_amount), 0.00),
    coalesce(sum(si.settlement_discount_amount), 0.00)
  into v_still_due, v_total_billed, v_settlement
  from public.sales_invoices si
  where si.billing_profile_id = any(v_bp_ids)
    and si.invoice_status = 'issued'::public.global_invoice_status;

  select
    coalesce(sum(ip.amount) filter (where coalesce(gp.method, '') <> 'wallet_credit'), 0.00),
    coalesce(sum(ip.amount) filter (where gp.method = 'wallet_credit'), 0.00)
  into v_collected_cash, v_wallet_applied
  from public.invoice_payments ip
  join public.global_payments gp on gp.id = ip.payment_id
  join public.sales_invoices si on si.id = ip.global_invoice_id
  where si.billing_profile_id = any(v_bp_ids)
    and si.invoice_status = 'issued'::public.global_invoice_status;

  select coalesce(wa.available_balance, 0.0000)
  into v_store_credit
  from public.wallet_accounts wa
  where wa.parent_tenant_id = v_books_id
    and wa.entity_type = 'customer'
    and wa.entity_id = v_billing_profile_id
    and wa.currency_code = 'BDT';

  select coalesce(sum(gp.unallocated_amount), 0.00)
  into v_unallocated
  from public.global_payments gp
  where gp.billing_profile_id = any(v_bp_ids);

  select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  into v_open_invoices
  from (
    select
      si.id,
      si.invoice_no,
      si.invoice_type::text as invoice_type,
      si.due_amount,
      si.paid_amount,
      si.total_amount,
      si.payment_status,
      si.invoice_date,
      si.due_date,
      si.issued_by_tenant_id,
      it.name as issued_by_tenant_name
    from public.sales_invoices si
    left join public.tenants it on it.id = si.issued_by_tenant_id
    where si.billing_profile_id = any(v_bp_ids)
      and si.invoice_status = 'issued'::public.global_invoice_status
      and si.due_amount > 0
    order by si.due_amount desc, si.invoice_date desc, si.id desc
    limit 50
  ) r;

  select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  into v_recent_payments
  from (
    select
      gp.id as payment_id,
      gp.payment_date,
      gp.method,
      gp.amount,
      gp.unallocated_amount,
      gp.note,
      ip.global_invoice_id as invoice_id,
      ip.amount as allocated_amount
    from public.global_payments gp
    left join public.invoice_payments ip on ip.payment_id = gp.id
    where gp.billing_profile_id = any(v_bp_ids)
    order by gp.payment_date desc, gp.id desc
    limit 30
  ) r;

  select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  into v_recent_ledger
  from (
    select
      l.id,
      l.type,
      l.amount,
      l.balance_after,
      l.operating_tenant_id,
      l.source_type,
      l.source_id,
      l.created_at,
      l.metadata->>'transaction_type' as transaction_type,
      coalesce(
        l.metadata->>'label',
        l.metadata->>'transaction_type',
        'Adjustment'
      ) as label
    from public.universal_wallet_ledger l
    where l.parent_tenant_id = v_books_id
      and l.entity_type = 'customer'
      and l.entity_id = any(v_bp_ids)
    order by l.created_at desc, l.id desc
    limit 30
  ) r;

  select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  into v_shop_access
  from (
    select
      s.id as shop_id,
      s.name as shop_name,
      s.shop_type::text as shop_type,
      st.id as shop_tenant_id,
      st.name as shop_tenant_name,
      scga.status,
      scga.credit_limit_amount
    from public.shop_customer_group_access scga
    join public.shops s on s.id = scga.shop_id
    join public.tenants st on st.id = s.tenant_id
    where scga.customer_group_id = p_customer_group_id
    order by st.name, s.name
    limit 20
  ) r;

  return jsonb_build_object(
    'success', true,
    'books_tenant_id', v_books_id,
    'billing_profile_id', v_billing_profile_id,
    'still_due', v_still_due,
    'total_billed', v_total_billed,
    'collected_cash', v_collected_cash,
    'wallet_applied', v_wallet_applied,
    'settlement', v_settlement,
    'store_credit_balance', v_store_credit,
    'unallocated_payments', v_unallocated,
    'open_invoices', v_open_invoices,
    'recent_payments', v_recent_payments,
    'recent_ledger', v_recent_ledger,
    'shop_access', v_shop_access
  );
end;
$$;

grant execute on function public.resolve_billing_profile_for_customer_group(bigint, bigint) to authenticated;
grant execute on function public.get_customer_account_summary_for_staff(bigint, bigint) to authenticated;

commit;
