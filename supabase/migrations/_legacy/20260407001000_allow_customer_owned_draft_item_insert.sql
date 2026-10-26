-- =========================================================
-- Allow customer item creation only on their own draft files.
-- Admin/staff keep existing insert access.
-- =========================================================

create or replace function public.create_costing_file_item_request(
  p_costing_file_id bigint,
  p_website_url text,
  p_quantity integer
)
returns table(
  id bigint,
  costing_file_id bigint,
  website_url text,
  quantity integer,
  status public.costing_file_item_status,
  created_by_email text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with inserted as (
    insert into public.costing_file_items (
      costing_file_id,
      website_url,
      quantity
    )
    select
      cf.id,
      trim(p_website_url),
      p_quantity
    from public.costing_files cf
    where cf.id = p_costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
        or (
          cf.status = 'draft'
          and public.can_customer_access_costing_file(cf.customer_group_id)
          and lower(trim(cf.created_by_email)) = public.current_user_email()
        )
      )
    returning
      id,
      costing_file_id,
      website_url,
      quantity,
      status,
      created_by_email,
      created_at,
      updated_at
  )
  select *
  from inserted;
$$;

grant execute on function public.create_costing_file_item_request(bigint, text, integer)
to authenticated;

drop policy if exists "costing_file_items_insert" on public.costing_file_items;
create policy "costing_file_items_insert"
on public.costing_file_items
for insert
to authenticated
with check (
  exists (
    select 1
    from public.costing_files cf
    where cf.id = costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
        or (
          cf.status = 'draft'
          and public.can_customer_access_costing_file(cf.customer_group_id)
          and lower(trim(cf.created_by_email)) = public.current_user_email()
        )
      )
  )
);
