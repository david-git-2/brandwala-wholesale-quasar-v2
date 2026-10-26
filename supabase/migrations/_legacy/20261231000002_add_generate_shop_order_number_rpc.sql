-- Migration: Fix missing generate_shop_order_number function and update submit_shop_order_from_cart
begin;

create or replace function public.generate_shop_order_number(
  p_tenant_id bigint,
  p_shop_id bigint
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_no text;
begin
  v_order_no := 'ORD-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(floor(random() * 100000)::text, 5, '0');
  return v_order_no;
end;
$$;

grant execute on function public.generate_shop_order_number(bigint, bigint) to authenticated;

commit;
