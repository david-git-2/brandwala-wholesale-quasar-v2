-- Explicitly allow staff to move files from customer_submitted to in_review.

create or replace function public.update_costing_file_status(
  p_id bigint,
  p_status public.costing_file_status
)
returns table(
  id bigint,
  status public.costing_file_status,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with updated as (
    update public.costing_files cf
    set status = p_status
    where cf.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or (
          public.can_staff_access_costing_file(cf.tenant_id)
          and cf.status = 'customer_submitted'
          and p_status = 'in_review'
        )
        or (
          public.can_customer_access_costing_file(cf.customer_group_id)
          and cf.status = 'draft'
          and p_status = 'customer_submitted'
        )
      )
    returning
      cf.id,
      cf.status,
      cf.updated_at
  )
  select *
  from updated;
$$;

grant execute on function public.update_costing_file_status(bigint, public.costing_file_status)
to authenticated;
