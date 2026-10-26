-- Migration: Add note column to commerce_invoices and update update_commerce_invoice_charges RPC
begin;

-- Add note column to commerce_invoices
alter table public.commerce_invoices add column if not exists note text;

-- Drop old function signature
drop function if exists public.update_commerce_invoice_charges(
  bigint, numeric, numeric, numeric, numeric, numeric, numeric, date, text, text, text, integer, numeric, numeric, text, text, text, text
);

-- Re-create function with p_note parameter
create or replace function public.update_commerce_invoice_charges(
  p_invoice_id bigint,
  p_delivery_charge numeric default null,
  p_wrapping_charge numeric default null,
  p_cod numeric default null,
  p_print_charge numeric default null,
  p_amount_paid numeric default null,
  p_discount_amount numeric default null,
  p_invoice_date date default null,
  p_delivered_by text default null,
  p_brand_name text default null,
  p_brand_address text default null,
  p_total_boxes integer default null,
  p_advance_amount numeric default null,
  p_previous_due numeric default null,
  p_thank_you_message text default null,
  p_client_name text default null,
  p_client_tr text default null,
  p_status text default null,
  p_note text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.commerce_invoices;
  v_order public.commerce_orders;
begin
  update public.commerce_invoices
  set
    delivery_charge = coalesce(p_delivery_charge, delivery_charge),
    wrapping_charge = coalesce(p_wrapping_charge, wrapping_charge),
    cod = coalesce(p_cod, cod),
    print_charge = coalesce(p_print_charge, print_charge),
    amount_paid = coalesce(p_amount_paid, amount_paid),
    discount_amount = coalesce(p_discount_amount, discount_amount),
    invoice_date = coalesce(p_invoice_date, invoice_date),
    delivered_by = p_delivered_by,
    brand_name = p_brand_name,
    brand_address = p_brand_address,
    total_boxes = p_total_boxes,
    advance_amount = coalesce(p_advance_amount, advance_amount),
    previous_due = coalesce(p_previous_due, previous_due),
    thank_you_message = p_thank_you_message,
    client_name = p_client_name,
    client_tr = p_client_tr,
    status = coalesce(p_status, status),
    note = p_note
  where id = p_invoice_id
  returning * into v_invoice;

  select * into v_order from public.commerce_orders where id = v_invoice.order_id;

  return json_build_object(
    'invoice', row_to_json(v_invoice),
    'order', row_to_json(v_order)
  );
end;
$$;

grant execute on function public.update_commerce_invoice_charges(
  bigint, numeric, numeric, numeric, numeric, numeric, numeric, date, text, text, text, integer, numeric, numeric, text, text, text, text, text
) to authenticated;

commit;
