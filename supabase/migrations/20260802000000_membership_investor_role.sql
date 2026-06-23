-- Add investor membership role for tenant-admin portal provisioning

begin;

alter type public.app_role add value if not exists 'investor';

commit;

begin;

create or replace function public.can_update_membership_row(
  p_existing_tenant_id bigint,
  p_existing_role public.app_role
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select
    public.is_superadmin()
    or (
      public.is_tenant_admin(p_existing_tenant_id)
      and p_existing_role in ('staff', 'viewer', 'investor')
    )
$$;

create or replace function public.can_assign_membership_role(
  p_target_tenant_id bigint,
  p_target_role public.app_role
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select
    public.is_superadmin()
    or (
      public.is_tenant_admin(p_target_tenant_id)
      and p_target_role in ('staff', 'viewer', 'investor')
    )
$$;

commit;
