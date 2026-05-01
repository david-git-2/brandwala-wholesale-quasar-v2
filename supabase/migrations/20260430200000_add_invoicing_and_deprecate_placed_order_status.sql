begin;

do $$
begin
  if not exists (
    select 1
    from pg_enum e
    join pg_type t on t.oid = e.enumtypid
    where t.typname = 'order_status'
      and e.enumlabel = 'invoicing'
  ) then
    alter type public.order_status add value 'invoicing' after 'processing';
  end if;
end
$$;

update public.orders
set status = 'invoiced'::public.order_status
where status = 'placed'::public.order_status;

commit;
