-- list_customer_accounts: join wallet_accounts on parent books tenant (not operating child id)

begin;

create or replace function public.list_customer_accounts(
  p_tenant_id bigint,
  p_search text default null
)
returns table (
  id bigint,
  customer_group_id bigint,
  billing_profile_id bigint,
  group_name text,
  admin_name text,
  email text,
  phone text,
  address text,
  accent_color text,
  is_active boolean,
  member_count bigint,
  wallet_available_balance numeric,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_books_id bigint;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  return query
  select
    cg.id,
    cg.id as customer_group_id,
    bp.id as billing_profile_id,
    cg.name as group_name,
    coalesce(bp.name, cg.name) as admin_name,
    bp.email,
    bp.phone,
    bp.address,
    coalesce(cg.accent_color, bp.color, '#B45F34') as accent_color,
    cg.is_active,
    coalesce(mem.cnt, 0::bigint) as member_count,
    coalesce(wa.available_balance, 0.00) as wallet_available_balance,
    cg.created_at
  from public.customer_groups cg
  left join public.billing_profiles bp
    on bp.customer_group_id = cg.id
   and (
     bp.tenant_id = v_books_id
     or bp.tenant_id in (select t.id from public.tenants t where t.parent_id = v_books_id)
   )
  left join (
    select cgm.customer_group_id as c_group_id, count(*) as cnt
    from public.customer_group_members cgm
    group by cgm.customer_group_id
  ) mem on mem.c_group_id = cg.id
  left join public.wallet_accounts wa
    on wa.parent_tenant_id = v_books_id
   and wa.entity_type = 'customer'
   and wa.entity_id = bp.id
   and wa.currency_code = 'BDT'
  where cg.tenant_id = p_tenant_id
    and (
      p_search is null
      or trim(p_search) = ''
      or cg.name ilike '%' || trim(p_search) || '%'
      or bp.name ilike '%' || trim(p_search) || '%'
      or bp.email ilike '%' || trim(p_search) || '%'
      or bp.phone ilike '%' || trim(p_search) || '%'
      or bp.address ilike '%' || trim(p_search) || '%'
    )
  order by cg.id desc;
end;
$$;

grant all on function public.list_customer_accounts(bigint, text) to authenticated;

commit;
