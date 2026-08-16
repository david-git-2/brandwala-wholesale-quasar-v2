-- SI8: global_invoices* → sales_invoices*. Compatibility views keep SQL RPCs
-- compiling. New RPC names; old names stay as thin wrappers.

begin;

alter table public.global_invoices rename to sales_invoices;
alter table public.global_invoice_items rename to sales_invoice_items;
alter table public.global_return_items rename to sales_return_items;

create view public.global_invoices
  with (security_invoker = true)
  as select * from public.sales_invoices;

create view public.global_invoice_items
  with (security_invoker = true)
  as select * from public.sales_invoice_items;

create view public.global_return_items
  with (security_invoker = true)
  as select * from public.sales_return_items;

revoke all on public.global_invoices from anon, authenticated;
revoke all on public.global_invoice_items from anon, authenticated;
revoke all on public.global_return_items from anon, authenticated;

grant select, insert, update, delete on public.sales_invoices to authenticated, service_role;
grant select, insert, update, delete on public.sales_invoice_items to authenticated, service_role;
grant select, insert, update, delete on public.sales_return_items to authenticated, service_role;

comment on table public.sales_invoices is
  'Sales invoices. tenant_id = parent books, issued_by_tenant_id = selling child.';

-- Desk create / dropship overloads → create_sales_invoice
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'create_global_invoice'
  loop
    execute format('alter function %s rename to create_sales_invoice', r.sig);
  end loop;

  if exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'post_global_invoice'
  ) then
    execute 'alter function public.post_global_invoice(bigint) rename to post_sales_invoice';
  end if;

  if exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'void_global_invoice'
  ) then
    execute 'alter function public.void_global_invoice(bigint) rename to void_sales_invoice';
  end if;

  if exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'unpost_global_invoice'
  ) then
    execute 'alter function public.unpost_global_invoice(bigint) rename to unpost_sales_invoice';
  end if;
end $$;

create function public.create_global_invoice(
  p_tenant_id bigint,
  p_invoice_no text,
  p_invoice_type public.global_invoice_type,
  p_billing_profile_id bigint default null,
  p_recipient_profile_id bigint default null,
  p_recipient_name text default null,
  p_recipient_phone text default null,
  p_recipient_address text default null,
  p_retail_billing_mode public.retail_billing_mode default null,
  p_due_date date default null,
  p_note text default null,
  p_invoice_date date default null
)
returns public.sales_invoices
language sql
security definer
set search_path = public
as $$
  select * from public.create_sales_invoice(
    p_tenant_id,
    p_invoice_no,
    p_invoice_type,
    p_billing_profile_id,
    p_recipient_profile_id,
    p_recipient_name,
    p_recipient_phone,
    p_recipient_address,
    p_retail_billing_mode,
    p_due_date,
    p_note,
    p_invoice_date
  );
$$;

create function public.create_global_invoice(
  p_tenant_id bigint,
  p_invoice_no text,
  p_billing_profile_id bigint,
  p_invoice_type public.global_invoice_type default 'wholesale',
  p_source_module public.global_source_module default 'wholesale',
  p_recipient_name text default null,
  p_recipient_phone text default null,
  p_recipient_address text default null,
  p_recipient_party_id bigint default null,
  p_middle_man_payout_amount numeric default null,
  p_note text default null
)
returns public.sales_invoices
language sql
security definer
set search_path = public
as $$
  select * from public.create_sales_invoice(
    p_tenant_id,
    p_invoice_no,
    p_billing_profile_id,
    p_invoice_type,
    p_source_module,
    p_recipient_name,
    p_recipient_phone,
    p_recipient_address,
    p_recipient_party_id,
    p_middle_man_payout_amount,
    p_note
  );
$$;

create function public.post_global_invoice(p_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.post_sales_invoice(p_invoice_id);
end;
$$;

create function public.void_global_invoice(p_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.void_sales_invoice(p_invoice_id);
end;
$$;

create function public.unpost_global_invoice(p_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.unpost_sales_invoice(p_invoice_id);
end;
$$;

grant execute on function public.create_sales_invoice(
  bigint, text, public.global_invoice_type, bigint, bigint, text, text, text,
  public.retail_billing_mode, date, text, date
) to authenticated, service_role;

grant execute on function public.create_sales_invoice(
  bigint, text, bigint, public.global_invoice_type, public.global_source_module,
  text, text, text, bigint, numeric, text
) to authenticated, service_role;

grant execute on function public.post_sales_invoice(bigint) to authenticated, service_role;
grant execute on function public.void_sales_invoice(bigint) to authenticated, service_role;
grant execute on function public.unpost_sales_invoice(bigint) to authenticated, service_role;

grant execute on function public.create_global_invoice(
  bigint, text, public.global_invoice_type, bigint, bigint, text, text, text,
  public.retail_billing_mode, date, text, date
) to authenticated, service_role;

grant execute on function public.create_global_invoice(
  bigint, text, bigint, public.global_invoice_type, public.global_source_module,
  text, text, text, bigint, numeric, text
) to authenticated, service_role;

grant execute on function public.post_global_invoice(bigint) to authenticated, service_role;
grant execute on function public.void_global_invoice(bigint) to authenticated, service_role;
grant execute on function public.unpost_global_invoice(bigint) to authenticated, service_role;

do $$
begin
  assert to_regclass('public.sales_invoices') is not null, 'SI8: sales_invoices missing';
  assert to_regclass('public.sales_invoice_items') is not null, 'SI8: sales_invoice_items missing';
  assert to_regclass('public.sales_return_items') is not null, 'SI8: sales_return_items missing';
  assert exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'create_sales_invoice'
  ), 'SI8: create_sales_invoice missing';
end $$;

commit;
