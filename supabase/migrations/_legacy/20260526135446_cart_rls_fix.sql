begin;

drop policy if exists koba_carts_insert on public.koba_carts;

create policy koba_carts_insert
on public.koba_carts
for insert
to authenticated
with check (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
  or exists (
    select 1
    from public.customer_groups cg
    where cg.id = customer_group_id
      and cg.tenant_id = koba_carts.tenant_id
  )
);

commit;