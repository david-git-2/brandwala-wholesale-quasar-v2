-- Allow staff who can manage customer groups to delete them.
-- Direct table deletes fail without a DELETE policy; cascade is blocked by child RLS.
-- SECURITY DEFINER RPC checks can_manage_customer_group, then deletes the row.

begin;

drop policy if exists "customer_groups_delete" on public.customer_groups;

create policy "customer_groups_delete"
on public.customer_groups
for delete
to authenticated
using (public.can_manage_customer_group(tenant_id));

create or replace function public.delete_customer_group(p_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
begin
  select cg.tenant_id into v_tenant_id
  from public.customer_groups cg
  where cg.id = p_id;

  if v_tenant_id is null then
    raise exception 'Customer group not found';
  end if;

  if not public.can_manage_customer_group(v_tenant_id) then
    raise exception 'Unauthorized';
  end if;

  if exists (
    select 1
    from public.shop_orders so
    where so.customer_group_id = p_id
  ) then
    raise exception 'Cannot delete customer group: shop orders exist';
  end if;

  if exists (
    select 1
    from public.billing_profiles bp
    join public.global_invoices gi on gi.billing_profile_id = bp.id
    where bp.customer_group_id = p_id
  ) then
    raise exception 'Cannot delete customer group: invoices exist for its billing profile';
  end if;

  delete from public.customer_groups where id = p_id;
end;
$$;

revoke all on function public.delete_customer_group(bigint) from public;
grant execute on function public.delete_customer_group(bigint) to authenticated;

commit;
