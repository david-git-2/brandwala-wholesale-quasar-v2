begin;

update public.orders
set status = 'invoiced'::public.order_status
where status::text = 'placed';

do $$
begin
  if exists (
    select 1
    from pg_type t
    join pg_enum e on e.enumtypid = t.oid
    where t.typname = 'order_status'
      and e.enumlabel = 'placed'
  ) then
    create type public.order_status_new as enum (
      'customer_submit',
      'direct_priced',
      'priced',
      'negotiate',
      'final_offered',
      'ordered',
      'processing',
      'invoicing',
      'invoiced'
    );

    alter table public.orders
      alter column status drop default;

    alter table public.orders
      alter column status type public.order_status_new
      using status::text::public.order_status_new;

    alter table public.orders
      alter column status set default 'customer_submit'::public.order_status_new;

    drop type public.order_status;
    alter type public.order_status_new rename to order_status;
  end if;
end
$$;

commit;
