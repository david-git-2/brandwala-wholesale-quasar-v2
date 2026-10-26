-- Migration: Drop old 6-parameter create_commerce_invoice function to prevent signature conflict
begin;

drop function if exists public.create_commerce_invoice(
  bigint, -- p_tenant_id
  bigint, -- p_order_id
  numeric, -- p_delivery_charge
  numeric, -- p_total_amount
  numeric, -- p_amount_paid
  text -- p_delivered_by
);

commit;
