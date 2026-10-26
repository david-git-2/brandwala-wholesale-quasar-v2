-- PBC costing files: store customer_group_id; stamp billing_profile_id from linked profile

alter table public.product_based_costing_files
  add column if not exists customer_group_id bigint null references public.customer_groups(id) on delete set null;

create index if not exists product_based_costing_files_customer_group_id_idx
  on public.product_based_costing_files (customer_group_id);

-- Backfill group from existing billing profile link
update public.product_based_costing_files f
set customer_group_id = bp.customer_group_id
from public.billing_profiles bp
where bp.id = f.billing_profile_id
  and f.customer_group_id is null
  and bp.customer_group_id is not null;

create or replace function public.trg_fn_pbc_files_stamp_billing_profile()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if new.customer_group_id is not null then
    select bp.id
    into new.billing_profile_id
    from public.billing_profiles bp
    where bp.customer_group_id = new.customer_group_id;

    if new.billing_profile_id is null then
      raise exception 'customer_group_id % has no linked billing profile', new.customer_group_id;
    end if;
  elsif tg_op = 'UPDATE' and new.customer_group_id is null and old.customer_group_id is not null then
    new.billing_profile_id := null;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_pbc_files_0_stamp_billing_profile on public.product_based_costing_files;

create trigger trg_pbc_files_0_stamp_billing_profile
  before insert or update of customer_group_id
  on public.product_based_costing_files
  for each row
  execute function public.trg_fn_pbc_files_stamp_billing_profile();

create or replace function public.list_product_based_costing_files(
  p_page integer default 1,
  p_page_size integer default 20,
  p_search text default null,
  p_status text default null,
  p_tenant_id bigint default null
) returns jsonb
language sql
stable
set search_path to 'public'
as $$
  with filtered as (
    select
      f.*,
      cg.name as customer_group_name,
      count(*) over() as total_count
    from public.product_based_costing_files f
    left join public.customer_groups cg on cg.id = f.customer_group_id
    where
      (p_tenant_id is null or f.tenant_id = p_tenant_id)
      and (
        coalesce(trim(p_search), '') = ''
        or coalesce(f.name, '') ilike ('%' || trim(p_search) || '%')
        or coalesce(f.order_for, '') ilike ('%' || trim(p_search) || '%')
        or coalesce(f.note, '') ilike ('%' || trim(p_search) || '%')
      )
      and (
        coalesce(trim(p_status), '') = ''
        or f.status = trim(p_status)
        or (trim(p_status) = 'procuring' and f.status = 'placing_order')
        or (trim(p_status) = 'delivered' and f.status = 'invoicing')
      )
  ),
  paged as (
    select *
    from filtered
    order by created_at desc, id desc
    offset (greatest(coalesce(p_page, 1), 1) - 1) * greatest(coalesce(p_page_size, 20), 1)
    limit greatest(coalesce(p_page_size, 20), 1)
  )
  select jsonb_build_object(
    'data',
    coalesce(jsonb_agg(to_jsonb(paged) - 'total_count'), '[]'::jsonb),
    'meta',
    jsonb_build_object(
      'total', coalesce(max(paged.total_count), 0),
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', greatest(coalesce(p_page_size, 20), 1),
      'total_pages',
      case
        when coalesce(max(paged.total_count), 0) = 0 then 1
        else ceil(coalesce(max(paged.total_count), 0)::numeric / greatest(coalesce(p_page_size, 20), 1))::int
      end
    )
  )
  from paged;
$$;
