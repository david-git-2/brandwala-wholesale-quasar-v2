begin;

do $$
begin
  if exists (
    select 1
    from pg_type
    where typname = 'order_status'
  ) and not exists (
    select 1
    from pg_enum e
    join pg_type t on t.oid = e.enumtypid
    where t.typname = 'order_status'
      and e.enumlabel = 'final_offered'
  ) then
    alter type public.order_status add value 'final_offered' after 'negotiate';
  end if;
end
$$;

commit;
