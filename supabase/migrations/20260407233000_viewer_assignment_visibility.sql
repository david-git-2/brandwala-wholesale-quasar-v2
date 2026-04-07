-- =========================================================
-- Viewer assignment visibility
-- Keep viewer access tied to the costing-file viewer list.
-- A viewer can see a costing file and its items only after
-- being added to that specific file and once it is completed.
-- =========================================================

create or replace function public.can_view_costing_file(
  p_costing_file_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.costing_files cf
    where cf.id = p_costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
        or (
          public.is_assigned_costing_file_viewer(cf.id)
          and cf.status = 'completed'
        )
        or (
          public.can_customer_access_costing_file(cf.customer_group_id)
          and (
            lower(trim(cf.created_by_email)) = public.current_user_email()
            or (
              cf.status = 'offered'
              and public.is_internal_costing_file_creator(cf.tenant_id, cf.created_by_email)
            )
          )
        )
      )
  );
$$;

grant execute on function public.can_view_costing_file(bigint)
to authenticated;

create or replace function public.can_view_costing_file_items(
  p_costing_file_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.costing_files cf
    where cf.id = p_costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
        or (
          public.is_assigned_costing_file_viewer(cf.id)
          and cf.status = 'completed'
        )
        or (
          public.can_customer_access_costing_file(cf.customer_group_id)
          and (
            lower(trim(cf.created_by_email)) = public.current_user_email()
            or (
              cf.status = 'offered'
              and public.is_internal_costing_file_creator(cf.tenant_id, cf.created_by_email)
            )
          )
        )
      )
  );
$$;

grant execute on function public.can_view_costing_file_items(bigint)
to authenticated;
