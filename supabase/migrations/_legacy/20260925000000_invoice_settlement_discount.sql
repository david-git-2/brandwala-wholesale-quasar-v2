-- Migration: Invoice settlement discount / write-off
-- Adds a post-post settlement discount so a posted invoice can be closed when the
-- customer pays less than billed. Separate from the pre-post discount_amount.

begin;

-- =========================================================
-- 1. Column
-- =========================================================
alter table public.global_invoices
  add column if not exists settlement_discount_amount numeric(12,2) not null default 0
    check (settlement_discount_amount >= 0);

-- =========================================================
-- 2. recompute_global_invoice_totals — subtract settlement_discount_amount
-- =========================================================
create or replace function public.recompute_global_invoice_totals(p_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_subtotal numeric(12,2);
  v_face_subtotal numeric(12,2);
  v_returned_subtotal numeric(12,2);
  v_returned_face_subtotal numeric(12,2);
  v_returned_charge numeric(12,2);
  v_invoice public.global_invoices;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then return; end if;

  -- Sum items
  select
    coalesce(sum(line_total_amount), 0.00),
    coalesce(sum(line_face_total_amount), 0.00)
  into v_subtotal, v_face_subtotal
  from public.global_invoice_items
  where invoice_id = p_invoice_id;

  -- Sum returns
  select
    coalesce(sum(return_accounting_amount), 0.00),
    coalesce(sum(return_face_amount), 0.00),
    coalesce(sum(return_charge_amount), 0.00)
  into v_returned_subtotal, v_returned_face_subtotal, v_returned_charge
  from public.global_return_items
  where invoice_id = p_invoice_id;

  -- Apply returns
  v_subtotal := greatest(v_subtotal - v_returned_subtotal, 0.00);
  v_face_subtotal := greatest(v_face_subtotal - greatest(v_returned_face_subtotal - v_returned_charge, 0.00), 0.00);

  update public.global_invoices
  set
    subtotal_amount = v_subtotal,
    face_subtotal_amount = v_face_subtotal,
    accounting_subtotal_amount = v_subtotal,
    middle_man_payout_amount = case
      when invoice_type = 'dropship'::public.global_invoice_type then greatest(v_face_subtotal - v_subtotal, 0.00)
      else 0.00
    end,
    total_amount = greatest(case
      when invoice_type = 'dropship'::public.global_invoice_type then v_face_subtotal + shipping_charge + cod_charge + wrapping_charge + print_charge - discount_amount - coalesce(settlement_discount_amount, 0.00)
      else v_subtotal + shipping_charge + cod_charge + wrapping_charge + print_charge - discount_amount - coalesce(settlement_discount_amount, 0.00)
    end, 0.00),
    due_amount = greatest(case
      when invoice_type = 'dropship'::public.global_invoice_type then v_face_subtotal + shipping_charge + cod_charge + wrapping_charge + print_charge - discount_amount - coalesce(settlement_discount_amount, 0.00)
      else v_subtotal + shipping_charge + cod_charge + wrapping_charge + print_charge - discount_amount - coalesce(settlement_discount_amount, 0.00)
    end - paid_amount, 0.00)
  where id = p_invoice_id;

  -- Recompute payment status
  perform public.recompute_global_invoice_payment_status(p_invoice_id);
end;
$$;

-- =========================================================
-- 3. apply_global_invoice_settlement_discount
-- =========================================================
create or replace function public.apply_global_invoice_settlement_discount(
  p_invoice_id bigint,
  p_amount numeric,
  p_note text default null
)
returns public.global_invoices
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'posted'::public.global_invoice_status then
    raise exception 'cannot settle a non-posted invoice';
  end if;
  if coalesce(p_amount, 0.00) < 0.00 then
    raise exception 'settlement amount must be 0 or greater';
  end if;
  if coalesce(p_amount, 0.00) > coalesce(v_invoice.due_amount, 0.00) then
    raise exception 'settlement amount exceeds outstanding due';
  end if;

  update public.global_invoices
  set
    settlement_discount_amount = coalesce(settlement_discount_amount, 0.00) + p_amount,
    note = coalesce(nullif(trim(p_note), ''), note),
    updated_at = now()
  where id = p_invoice_id;

  perform public.recompute_global_invoice_totals(p_invoice_id);

  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  return v_invoice;
end;
$$;

grant execute on function public.apply_global_invoice_settlement_discount(bigint, numeric, text) to authenticated;

commit;
