-- Payments desk: parent tenant cash on get_wallet_dashboard_summary (payments grant + ledger fallback)

begin;

create or replace function public.get_wallet_dashboard_summary(p_tenant_id bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_books_id bigint;
  v_tenant_cash numeric(18,4) := 0.0000;
  v_courier_cod_holding numeric(18,4) := 0.0000;
  v_merchant_pending numeric(18,4) := 0.0000;
  v_merchant_available numeric(18,4) := 0.0000;
  v_vendor_payables numeric(18,4) := 0.0000;
  v_customer_deposits numeric(18,4) := 0.0000;
  v_ledger_cash numeric(18,4);
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not (
    public.wallet_staff_can_view(p_tenant_id)
    or public.membership_has_module_action(v_books_id, 'payments', 'view')
    or public.membership_has_module_action(p_tenant_id, 'payments', 'view')
    or public.is_tenant_staff(p_tenant_id)
  ) then
    return jsonb_build_object(
      'success', false,
      'error', 'access denied',
      'tenant_id', v_books_id,
      'parent_tenant_id', v_books_id,
      'tenant_cash_total', 0,
      'courier_cod_holding_total', 0,
      'merchant_pending_total', 0,
      'merchant_available_total', 0,
      'vendor_payables_total', 0,
      'customer_deposits_total', 0
    );
  end if;

  select coalesce(w.available_balance, 0.0000)
  into v_tenant_cash
  from public.wallet_accounts w
  where w.parent_tenant_id = v_books_id
    and w.entity_type = 'tenant'
    and w.entity_id = v_books_id
    and w.currency_code = 'BDT'
  limit 1;

  select l.balance_after
  into v_ledger_cash
  from public.universal_wallet_ledger l
  where l.parent_tenant_id = v_books_id
    and l.entity_type = 'tenant'
    and l.entity_id = v_books_id
    and coalesce(l.currency_code, 'BDT') = 'BDT'
  order by l.id desc
  limit 1;

  if coalesce(v_tenant_cash, 0) = 0 and coalesce(v_ledger_cash, 0) <> 0 then
    v_tenant_cash := v_ledger_cash;
  end if;

  select
    coalesce(sum(case when entity_type = 'courier' then pending_balance + available_balance else 0 end), 0),
    coalesce(sum(case when entity_type in ('customer', 'middleman') then pending_balance else 0 end), 0),
    coalesce(sum(case when entity_type in ('customer', 'middleman') then available_balance else 0 end), 0),
    coalesce(sum(case when entity_type = 'vendor' then available_balance else 0 end), 0),
    coalesce(sum(case when entity_type = 'customer' then available_balance else 0 end), 0)
  into
    v_courier_cod_holding,
    v_merchant_pending,
    v_merchant_available,
    v_vendor_payables,
    v_customer_deposits
  from public.wallet_accounts
  where parent_tenant_id = v_books_id;

  return jsonb_build_object(
    'success', true,
    'tenant_id', v_books_id,
    'parent_tenant_id', v_books_id,
    'tenant_cash_total', coalesce(v_tenant_cash, 0),
    'courier_cod_holding_total', v_courier_cod_holding,
    'merchant_pending_total', v_merchant_pending,
    'merchant_available_total', v_merchant_available,
    'vendor_payables_total', v_vendor_payables,
    'customer_deposits_total', v_customer_deposits
  );
end;
$$;

commit;
