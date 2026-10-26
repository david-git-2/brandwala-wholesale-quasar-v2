begin;

do $$
begin
  if not exists (
    select 1
    from pg_enum e
    join pg_type t on t.oid = e.enumtypid
    where t.typname = 'order_status'
      and e.enumlabel = 'invoiced'
  ) then
    alter type public.order_status add value 'invoiced' after 'processing';
  end if;
end
$$;

commit;
