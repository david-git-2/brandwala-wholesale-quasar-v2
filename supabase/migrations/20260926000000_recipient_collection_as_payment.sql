begin;

-- =========================================================
-- 1. Allow profile-less (COD/recipient) payments + tag source
-- =========================================================
alter table public.global_payments
  alter column billing_profile_id drop not null;

alter table public.global_payments
  add column if not exists collection_source public.collection_source_type not null default 'billing_profile';

-- =========================================================
-- 2. Rewrite record_recipient_invoice_collection as a real transaction
-- =========================================================
drop function if exists public.record_recipient_invoice_collection(bigint, numeric, text) cascade;

create or replace function public.record_recipient_invoice_collection(
  p_global_invoice_id bigint,
  p_amount numeric,
  p_payment_date date default null,
  p_method text default 'cash',
  p_reference text default null,
  p_note text default null
)
returns public.global_invoices
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_payment_id bigint;
begin
  select * into v_invoice from public.global_invoices where id = p_global_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.collection_source <> 'recipient'::public.collection_source_type then
    raise exception 'This invoice does not collect from recipient.';
  end if;
  if coalesce(p_amount, 0.00) <= 0.00 then raise exception 'Amount must be positive.'; end if;

  insert into public.global_payments (
    tenant_id,
    billing_profile_id,
    collection_source,
    amount,
    unallocated_amount,
    payment_date,
    method,
    reference,
    note
  )
  values (
    v_invoice.tenant_id,
    null,
    'recipient'::public.collection_source_type,
    p_amount,
    0.00,
    coalesce(p_payment_date, current_date),
    p_method,
    p_reference,
    nullif(trim(p_note), '')
  )
  returning id into v_payment_id;

  insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
  values (v_invoice.tenant_id, v_payment_id, p_global_invoice_id, p_amount);

  update public.global_invoices
  set
    paid_amount = coalesce(paid_amount, 0.00) + p_amount,
    note = coalesce(nullif(trim(p_note), ''), note),
    updated_at = now()
  where id = p_global_invoice_id
  returning * into v_invoice;

  perform public.recompute_global_invoice_payment_status(p_global_invoice_id);

  return v_invoice;
end;
$$;

grant execute on function public.record_recipient_invoice_collection(bigint, numeric, date, text, text, text) to authenticated;

commit;
