-- Delete customer group: cascade members + shop access; nullify historical transaction links.

begin;

-- shop_orders: keep order history, drop group link
alter table public.shop_orders
  alter column customer_group_id drop not null;

alter table public.shop_orders
  drop constraint if exists shop_orders_customer_group_id_fkey;

alter table public.shop_orders
  add constraint shop_orders_customer_group_id_fkey
  foreign key (customer_group_id)
  references public.customer_groups(id)
  on delete set null;

-- sales invoices: keep invoice history, drop billing profile link
alter table public.sales_invoices
  drop constraint if exists global_invoices_billing_profile_id_fkey;

alter table public.sales_invoices
  add constraint global_invoices_billing_profile_id_fkey
  foreign key (billing_profile_id)
  references public.billing_profiles(id)
  on delete set null;

-- global payments: keep payment history, drop billing profile link
alter table public.global_payments
  drop constraint if exists payments_billing_profile_id_fkey;

alter table public.global_payments
  add constraint payments_billing_profile_id_fkey
  foreign key (billing_profile_id)
  references public.billing_profiles(id)
  on delete set null;

create or replace function public.delete_customer_group(p_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
begin
  select cg.tenant_id into v_tenant_id
  from public.customer_groups cg
  where cg.id = p_id;

  if v_tenant_id is null then
    raise exception 'Customer group not found';
  end if;

  if not public.can_manage_customer_group(v_tenant_id) then
    raise exception 'Unauthorized';
  end if;

  -- Wallet rows have no FK to billing_profiles; remove before profile cascade.
  delete from public.wallet_accounts wa
  using public.billing_profiles bp
  where bp.customer_group_id = p_id
    and wa.entity_type = 'customer'
    and wa.entity_id = bp.id;

  delete from public.customer_groups where id = p_id;
end;
$$;

revoke all on function public.delete_customer_group(bigint) from public;
grant execute on function public.delete_customer_group(bigint) to authenticated;

commit;
