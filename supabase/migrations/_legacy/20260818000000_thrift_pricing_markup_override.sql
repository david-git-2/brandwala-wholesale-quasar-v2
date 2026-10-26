-- Thrift: per-item markup_rate_override on thrift_pricings + list RPC field
begin;

alter table public.thrift_pricings
  add column if not exists markup_rate_override numeric null;

create or replace function public.list_thrift_stocks_paginated(
  p_tenant_id bigint,
  p_page integer default 1,
  p_page_size integer default 20,
  p_search text default null,
  p_status text default null,
  p_condition text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(coalesce(p_page_size, 20), 1);
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_status text := nullif(trim(coalesce(p_status, '')), '');
  v_condition text := nullif(trim(coalesce(p_condition, '')), '');
begin
  if not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Not authorized for this tenant';
  end if;

  with filtered as materialized (
    select s.*
    from public.thrift_stocks s
    where s.tenant_id = p_tenant_id
      and (v_status is null or s.status::text = v_status)
      and (v_condition is null or s.condition::text = v_condition)
      and (
        v_search is null
        or s.name ilike '%' || v_search || '%'
        or s.brand_name ilike '%' || v_search || '%'
        or s.barcode ilike '%' || v_search || '%'
      )
  ),
  counts as (
    select count(*)::bigint as total
    from filtered
  ),
  paged as (
    select s.*
    from filtered s
    order by s.created_at desc
    offset (v_page - 1) * v_page_size
    limit v_page_size
  ),
  rows as (
    select
      jsonb_build_object(
        'id', s.id,
        'tenant_id', s.tenant_id,
        'shipment_id', s.shipment_id,
        'box_id', s.box_id,
        'name', s.name,
        'brand_name', s.brand_name,
        'category_id', s.category_id,
        'type_id', s.type_id,
        'section', s.section,
        'shelf_id', s.shelf_id,
        'color', s.color,
        'size', s.size,
        'condition', s.condition,
        'barcode', s.barcode,
        'stock_type', s.stock_type,
        'quantity', s.quantity,
        'product_weight', s.product_weight,
        'extra_weight', s.extra_weight,
        'status', s.status,
        'note', s.note,
        'origin_unit_price', s.origin_unit_price,
        'extra_origin_unit_price', s.extra_origin_unit_price,
        'additional_charges_cost', s.additional_charges_cost,
        'inserted_by', s.inserted_by,
        'created_at', s.created_at,
        'updated_at', s.updated_at,
        'pricing', case
          when p.stock_id is not null then jsonb_build_object(
            'cost_of_goods_sold', p.cost_of_goods_sold,
            'target_price', p.target_price,
            'listed_unit_price', p.listed_unit_price,
            'is_listed_price_manual', p.is_listed_price_manual,
            'markup_rate_override', p.markup_rate_override,
            'extra_expense_cost', p.extra_expense_cost
          )
          else '{}'::jsonb
        end,
        'image_url', img.image_url,
        'drive_file_id', img.drive_file_id,
        'measurements', case
          when m.stock_id is not null then jsonb_build_object(
            'stock_id', m.stock_id,
            'tenant_id', m.tenant_id,
            'bust_in', m.bust_in,
            'waist_in', m.waist_in,
            'hips_in', m.hips_in,
            'length_in', m.length_in,
            'shoulder_width_in', m.shoulder_width_in,
            'sleeve_length_in', m.sleeve_length_in,
            'arm_circumference_in', m.arm_circumference_in,
            'hem_width_in', m.hem_width_in,
            'neck_opening_in', m.neck_opening_in,
            'sleeve_type', m.sleeve_type,
            'neckline', m.neckline,
            'dress_style', m.dress_style,
            'fabric_stretch', m.fabric_stretch,
            'lining', m.lining,
            'closure_type', m.closure_type,
            'measurement_notes', m.measurement_notes
          )
          else null
        end
      ) as row_data,
      s.created_at as sort_created_at
    from paged s
    left join public.thrift_pricings p on p.stock_id = s.id
    left join public.thrift_stock_measurements m on m.stock_id = s.id
    left join lateral (
      select i.image_url, i.drive_file_id
      from public.thrift_stock_images i
      where i.stock_id = s.id
        and i.is_primary = true
      limit 1
    ) img on true
  )
  select
    (select total from counts),
    coalesce(
      (select jsonb_agg(r.row_data order by r.sort_created_at desc) from rows r),
      '[]'::jsonb
    )
  into v_total_count, v_data;

  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::numeric / v_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', coalesce(v_data, '[]'::jsonb),
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', v_page,
      'page_size', v_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$$;

grant execute on function public.list_thrift_stocks_paginated(
  bigint, integer, integer, text, text, text
) to authenticated;

commit;
