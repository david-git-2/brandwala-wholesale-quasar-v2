-- Shipment-scoped global accounting ledger list for shipment accounting detail reports.

create index if not exists global_accounting_ledger_shipment_idx
  on public.global_accounting_ledger (shipment_id);

create or replace function public.list_global_accounting_ledger_by_shipment(
  p_parent_tenant_id bigint,
  p_shipment_id bigint,
  p_limit integer default 500,
  p_offset integer default 0
)
returns setof public.global_accounting_ledger
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.user_can_manage_parent_tenant(p_parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  select *
  from public.global_accounting_ledger l
  where l.parent_tenant_id = p_parent_tenant_id
    and l.shipment_id = p_shipment_id
  order by l.entry_date desc, l.id desc
  limit greatest(coalesce(p_limit, 500), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

grant execute on function public.list_global_accounting_ledger_by_shipment(bigint, bigint, integer, integer) to authenticated;
