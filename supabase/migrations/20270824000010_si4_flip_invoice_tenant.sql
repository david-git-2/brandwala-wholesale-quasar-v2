-- SI4: Historical invoices live under the parent. One invoice_no pool per company.
-- Prefix colliding numbers, then set tenant_id = parent_tenant_id.

begin;

-- Collisions after flip: same parent_tenant_id + invoice_no, different child tenant_id.
update public.global_invoices gi
set invoice_no = gi.issued_by_tenant_id::text || '-' || gi.invoice_no
where gi.tenant_id is distinct from gi.parent_tenant_id
  and exists (
    select 1
    from public.global_invoices x
    where x.parent_tenant_id = gi.parent_tenant_id
      and x.invoice_no = gi.invoice_no
      and x.id < gi.id
  );

update public.global_invoices
set tenant_id = parent_tenant_id
where tenant_id is distinct from parent_tenant_id;

update public.global_invoice_items gi
set tenant_id = i.tenant_id,
    parent_tenant_id = i.parent_tenant_id
from public.global_invoices i
where i.id = gi.invoice_id
  and (
    gi.tenant_id is distinct from i.tenant_id
    or gi.parent_tenant_id is distinct from i.parent_tenant_id
  );

update public.global_return_items ri
set tenant_id = i.tenant_id,
    parent_tenant_id = i.parent_tenant_id
from public.global_invoices i
where i.id = ri.invoice_id
  and (
    ri.tenant_id is distinct from i.tenant_id
    or ri.parent_tenant_id is distinct from i.parent_tenant_id
  );

update public.global_invoice_items gi
set assigned_child_tenant_id = sh.assigned_child_tenant_id
from public.global_shipment_items gsi
join public.global_shipments sh on sh.id = gsi.shipment_id
where gi.assigned_child_tenant_id is null
  and gi.shipment_item_id = gsi.id
  and sh.assigned_child_tenant_id is not null;

do $$
begin
  assert (
    select count(*)
    from public.global_invoices i
    join public.tenants t on t.id = i.tenant_id
    where t.parent_id is not null
  ) = 0, 'SI4: invoice tenant_id must not be a child';

  assert (
    select count(*)
    from (
      select tenant_id, invoice_no
      from public.global_invoices
      group by 1, 2
      having count(*) > 1
    ) d
  ) = 0, 'SI4: invoice_no must be unique per parent tenant_id';
end $$;

commit;
