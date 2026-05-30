-- Create helper to verify if the current user is a customer admin or negotiator for a customer group
create or replace function public.is_customer_group_admin_or_negotiator(
  p_customer_group_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.customer_group_members cgm
    where cgm.customer_group_id = p_customer_group_id
      and lower(trim(cgm.email)) = public.current_user_email()
      and cgm.role in ('admin', 'negotiator')
      and cgm.is_active = true
  )
$$;

grant execute on function public.is_customer_group_admin_or_negotiator(bigint)
to authenticated;

-- Update can_view_costing_file visibility rules
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
          and cf.status::text in ('po_placed', 'completed')
        )
        or (
          public.can_customer_access_costing_file(cf.customer_group_id)
          and (
            lower(trim(cf.created_by_email)) = public.current_user_email()
            or cf.status = 'draft'
            or public.is_customer_group_admin_or_negotiator(cf.customer_group_id)
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

-- Update can_view_costing_file_items visibility rules
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
          and cf.status::text in ('po_placed', 'completed')
        )
        or (
          public.can_customer_access_costing_file(cf.customer_group_id)
          and (
            lower(trim(cf.created_by_email)) = public.current_user_email()
            or cf.status = 'draft'
            or public.is_customer_group_admin_or_negotiator(cf.customer_group_id)
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
