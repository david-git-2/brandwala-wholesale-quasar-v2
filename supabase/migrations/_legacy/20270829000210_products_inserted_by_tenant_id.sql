-- Phase 1: audit column for who created a product. Catalog scope stays parent_tenant_id.
-- tenant_id is still present (dropped in a later phase).

alter table public.products
  add column if not exists inserted_by_tenant_id bigint;

create index if not exists products_inserted_by_tenant_id_idx
  on public.products using btree (inserted_by_tenant_id);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'products_inserted_by_tenant_id_fkey'
  ) then
    alter table public.products
      add constraint products_inserted_by_tenant_id_fkey
      foreign key (inserted_by_tenant_id)
      references public.tenants (id)
      on delete set null;
  end if;
end
$$;

update public.products
set inserted_by_tenant_id = tenant_id
where inserted_by_tenant_id is null
  and tenant_id is not null;
