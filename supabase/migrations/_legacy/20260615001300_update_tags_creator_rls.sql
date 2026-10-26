-- Migration: Update tags RLS policy to scope universal tags (tenant_id IS NULL) to shared creator memberships
begin;

-- Drop the old tags_select policy
drop policy if exists tags_select on public.tags;

-- Recreate tags_select policy with shared creator memberships for universal tags
create policy tags_select on public.tags
  for select to authenticated
  using (
    -- 1. If it's a tenant-specific tag, standard membership rules apply
    (tenant_id is not null and public.has_active_tenant_membership(tenant_id))
    or
    -- 2. If it's a global/shared tag (tenant_id is null), it is only visible if:
    --    The current user shares at least one active tenant membership with the tag's creator.
    (tenant_id is null and exists (
      select 1 
      from public.memberships m1
      join public.memberships m2 on m2.tenant_id = m1.tenant_id
      where lower(trim(m1.email)) = public.current_user_email()
        and lower(trim(m2.email)) = tags.created_by_email
        and m1.is_active = true
        and m2.is_active = true
    ))
  );

commit;
