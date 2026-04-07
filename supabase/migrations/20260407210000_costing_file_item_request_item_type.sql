-- =========================================================
-- Keep customer/staff item request RPC aligned with the new
-- item_type field so the API returns the selected type.
-- =========================================================

drop function if exists public.create_costing_file_item_request(bigint, text, integer, text);

create or replace function public.create_costing_file_item_request(
  p_costing_file_id bigint,
  p_website_url text,
  p_quantity integer,
  p_item_type text default null
)
returns table(
  id bigint,
  costing_file_id bigint,
  item_type text,
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
      item_type,
      website_url,
      quantity
    )
    select
      cf.id,
      nullif(trim(p_item_type), ''),
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
      item_type,
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

grant execute on function public.create_costing_file_item_request(bigint, text, integer, text)
to authenticated;
