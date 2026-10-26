-- SI7: parent_tenant_id is no longer a second owner. Keep the column as an
-- alias of tenant_id (books owner = parent). Do not drop; other modules select it.

begin;

update public.global_invoices
set parent_tenant_id = tenant_id
where parent_tenant_id is distinct from tenant_id;

update public.global_invoice_items gi
set parent_tenant_id = i.tenant_id,
    tenant_id = i.tenant_id
from public.global_invoices i
where i.id = gi.invoice_id
  and (
    gi.parent_tenant_id is distinct from i.tenant_id
    or gi.tenant_id is distinct from i.tenant_id
  );

update public.global_return_items ri
set parent_tenant_id = i.tenant_id,
    tenant_id = i.tenant_id
from public.global_invoices i
where i.id = ri.invoice_id
  and (
    ri.parent_tenant_id is distinct from i.tenant_id
    or ri.tenant_id is distinct from i.tenant_id
  );

create or replace function public.trg_invoice_parent_tenant_alias()
returns trigger
language plpgsql
as $$
begin
  new.parent_tenant_id := new.tenant_id;
  return new;
end;
$$;

drop trigger if exists trg_global_invoices_parent_tenant_alias on public.global_invoices;
create trigger trg_global_invoices_parent_tenant_alias
before insert or update of tenant_id, parent_tenant_id
on public.global_invoices
for each row
execute function public.trg_invoice_parent_tenant_alias();

drop trigger if exists trg_global_invoice_items_parent_tenant_alias on public.global_invoice_items;
create trigger trg_global_invoice_items_parent_tenant_alias
before insert or update of tenant_id, parent_tenant_id
on public.global_invoice_items
for each row
execute function public.trg_invoice_parent_tenant_alias();

drop trigger if exists trg_global_return_items_parent_tenant_alias on public.global_return_items;
create trigger trg_global_return_items_parent_tenant_alias
before insert or update of tenant_id, parent_tenant_id
on public.global_return_items
for each row
execute function public.trg_invoice_parent_tenant_alias();

do $$
begin
  assert (
    select count(*) from public.global_invoices
    where parent_tenant_id is distinct from tenant_id
  ) = 0, 'SI7: invoice parent_tenant_id must equal tenant_id';
end $$;

commit;
