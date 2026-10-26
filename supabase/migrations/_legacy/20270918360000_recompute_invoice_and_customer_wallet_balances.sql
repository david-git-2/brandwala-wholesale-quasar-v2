-- Rebuild invoice paid/due from allocations.
-- Rebuild customer wallet balances from ledger (store credit net).

begin;

do $$
declare
  r record;
begin
  for r in
    select id from public.sales_invoices where invoice_status = 'issued'
  loop
    perform public.recompute_global_invoice_payment_status(r.id);
  end loop;
end;
$$;

update public.wallet_accounts wa
set
  available_balance = coalesce((
    select sum(case when l.type = 'credit' then l.amount else -l.amount end)
    from public.universal_wallet_ledger l
    where l.entity_type = wa.entity_type
      and l.entity_id = wa.entity_id
      and l.parent_tenant_id = coalesce(wa.parent_tenant_id, wa.tenant_id)
  ), 0),
  updated_at = now()
where wa.entity_type = 'customer';

commit;
