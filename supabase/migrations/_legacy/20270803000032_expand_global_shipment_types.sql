-- Phase 4: expand global_shipment_type to international | local | transfer | thrift
-- Map legacy domestic → local

begin;

-- Rename legacy value (PG 10+)
do $$
begin
  if exists (
    select 1
    from pg_enum e
    join pg_type t on t.oid = e.enumtypid
    where t.typname = 'global_shipment_type'
      and e.enumlabel = 'domestic'
  ) then
    alter type public.global_shipment_type rename value 'domestic' to 'local';
  end if;
end
$$;

alter type public.global_shipment_type add value if not exists 'transfer';
alter type public.global_shipment_type add value if not exists 'thrift';

commit;
