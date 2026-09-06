-- Allow authenticated SELECT on tenants (RLS-gated) for PostgREST embeds
-- (e.g. sales_invoices issued_by tenant name). Parent admins can read child rows.

begin;

grant select on table public.tenants to authenticated;

drop policy if exists "members_can_view_tenants" on public.tenants;

create policy "members_can_view_tenants"
on public.tenants
for select
to authenticated
using (
  public.is_superadmin()
  or exists (
    select 1
    from public.memberships m
    where m.tenant_id = public.tenants.id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
  or (
    public.tenants.parent_id is not null
    and public.user_can_manage_parent_tenant(public.tenants.parent_id)
  )
);

drop function if exists public.list_child_tenant_refs(bigint[]);

create function public.list_child_tenant_refs(p_parent_tenant_ids bigint[])
returns table (
  id bigint,
  parent_id bigint,
  name text
)
language sql
stable
security definer
set search_path = public
as $$
  select t.id, t.parent_id, t.name
  from public.tenants t
  where t.parent_id = any (coalesce(p_parent_tenant_ids, array[]::bigint[]))
    and (
      public.is_superadmin()
      or public.user_can_manage_parent_tenant(t.parent_id)
    )
  order by t.parent_id, t.id;
$$;

grant execute on function public.list_child_tenant_refs(bigint[]) to authenticated;

commit;
