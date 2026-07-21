-- Migration: Fix shop_orders.courier_service_id type from bigint to uuid and link foreign key to courier_services(id)
begin;

alter table public.shop_orders
  alter column courier_service_id type uuid using courier_service_id::text::uuid;

-- Add foreign key constraint if it doesn't already exist
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_name = 'fk_shop_orders_courier_service'
      and table_name = 'shop_orders'
  ) then
    alter table public.shop_orders
      add constraint fk_shop_orders_courier_service
      foreign key (courier_service_id) references public.courier_services(id)
      on delete set null;
  end if;
end $$;

commit;
