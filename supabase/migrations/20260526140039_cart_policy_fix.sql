begin;

drop policy if exists koba_carts_select on public.koba_carts;
drop policy if exists koba_carts_update on public.koba_carts;
drop policy if exists koba_carts_delete on public.koba_carts;

create policy koba_carts_select
on public.koba_carts
for select
to authenticated
using (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
  or exists (
    select 1
    from public.customer_groups cg
    where cg.id = koba_carts.customer_group_id
      and cg.tenant_id = koba_carts.tenant_id
  )
);

create policy koba_carts_update
on public.koba_carts
for update
to authenticated
using (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
  or exists (
    select 1
    from public.customer_groups cg
    where cg.id = koba_carts.customer_group_id
      and cg.tenant_id = koba_carts.tenant_id
  )
)
with check (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
  or exists (
    select 1
    from public.customer_groups cg
    where cg.id = koba_carts.customer_group_id
      and cg.tenant_id = koba_carts.tenant_id
  )
);

create policy koba_carts_delete
on public.koba_carts
for delete
to authenticated
using (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
  or exists (
    select 1
    from public.customer_groups cg
    where cg.id = koba_carts.customer_group_id
      and cg.tenant_id = koba_carts.tenant_id
  )
);

commit;