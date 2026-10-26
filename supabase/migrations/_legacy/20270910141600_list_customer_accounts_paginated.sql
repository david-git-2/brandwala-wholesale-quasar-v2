-- Paginated customer hub list (jsonb data + meta), matching shipment list pattern.

begin;

create or replace function public.list_customer_accounts_paginated(
  p_tenant_id bigint,
  p_page integer default 1,
  p_page_size integer default 20,
  p_search text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_books_id bigint;
  v_page integer;
  v_page_size integer;
  v_total_count bigint;
  v_total_pages integer;
  v_data jsonb;
  v_search text;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_page := greatest(coalesce(p_page, 1), 1);
  v_page_size := greatest(1, least(coalesce(p_page_size, 20), 200));
  v_search := nullif(trim(coalesce(p_search, '')), '');

  select count(*)
  into v_total_count
  from public.customer_groups cg
  left join public.billing_profiles bp
    on bp.customer_group_id = cg.id
   and bp.parent_tenant_id = v_books_id
  where cg.parent_tenant_id = v_books_id
    and cg.deleted_at is null
    and (
      v_search is null
      or cg.name ilike '%' || v_search || '%'
      or bp.name ilike '%' || v_search || '%'
      or bp.email ilike '%' || v_search || '%'
      or bp.phone ilike '%' || v_search || '%'
      or bp.phone_country_code ilike '%' || v_search || '%'
      or bp.address ilike '%' || v_search || '%'
    );

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      cg.id as sort_id,
      jsonb_build_object(
        'id', cg.id,
        'customer_group_id', cg.id,
        'billing_profile_id', bp.id,
        'group_name', cg.name,
        'admin_name', coalesce(bp.name, cg.name),
        'email', bp.email,
        'phone', nullif(concat_ws(' ', bp.phone_country_code, bp.phone), ''),
        'address', bp.address,
        'accent_color', coalesce(cg.accent_color, '#B45F34'),
        'is_active', cg.is_active,
        'member_count', coalesce(mem.cnt, 0::bigint),
        'wallet_available_balance', coalesce(wa.available_balance, 0.00),
        'created_at', cg.created_at
      ) as row_json
    from public.customer_groups cg
    left join public.billing_profiles bp
      on bp.customer_group_id = cg.id
     and bp.parent_tenant_id = v_books_id
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
    where cg.parent_tenant_id = v_books_id
      and cg.deleted_at is null
      and (
        v_search is null
        or cg.name ilike '%' || v_search || '%'
        or bp.name ilike '%' || v_search || '%'
        or bp.email ilike '%' || v_search || '%'
        or bp.phone ilike '%' || v_search || '%'
        or bp.phone_country_code ilike '%' || v_search || '%'
        or bp.address ilike '%' || v_search || '%'
      )
    order by cg.id desc
    limit v_page_size
    offset (v_page - 1) * v_page_size
  ) q;

  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::numeric / v_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', v_page,
      'page_size', v_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$$;

revoke all on function public.list_customer_accounts_paginated(bigint, integer, integer, text) from public;
grant execute on function public.list_customer_accounts_paginated(bigint, integer, integer, text) to authenticated;

commit;
