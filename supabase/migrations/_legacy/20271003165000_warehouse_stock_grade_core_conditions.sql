-- BW warehouse condition tags (stock_grade / warehouse)

do $$
declare
  v_cat_wh bigint;
begin
  select id into v_cat_wh
  from public.tag_categories
  where module_key = 'stock_grade'
    and code = 'warehouse'
    and tenant_id is null;

  if v_cat_wh is null then
    raise exception 'stock_grade warehouse category missing';
  end if;

  insert into public.tags (
    category_id,
    slug,
    name,
    color,
    metadata,
    sort_order,
    is_system,
    is_active,
    group_name,
    type,
    created_by_email
  )
  values
    (
      v_cat_wh,
      'short_dated',
      'Short dated',
      '#eab308',
      '{"maps_to_availability": "held"}'::jsonb,
      6,
      true,
      true,
      'stock_grade',
      'stock_grade',
      'system'
    ),
    (
      v_cat_wh,
      'expired',
      'Expired',
      '#78716c',
      '{"maps_to_availability": "unsellable"}'::jsonb,
      7,
      true,
      true,
      'stock_grade',
      'stock_grade',
      'system'
    ),
    (
      v_cat_wh,
      'product_damage',
      'Product damaged',
      '#ea580c',
      '{"maps_to_availability": "unsellable"}'::jsonb,
      8,
      true,
      true,
      'stock_grade',
      'stock_grade',
      'system'
    ),
    (
      v_cat_wh,
      'stolen',
      'Stolen / shrinkage',
      '#991b1b',
      '{"maps_to_availability": "unsellable"}'::jsonb,
      9,
      true,
      true,
      'stock_grade',
      'stock_grade',
      'system'
    ),
    (
      v_cat_wh,
      'quarantine',
      'Quarantine',
      '#6366f1',
      '{"maps_to_availability": "held"}'::jsonb,
      10,
      true,
      true,
      'stock_grade',
      'stock_grade',
      'system'
    ),
    (
      v_cat_wh,
      'customer_return',
      'Customer return',
      '#a855f7',
      '{"maps_to_availability": "held"}'::jsonb,
      11,
      true,
      true,
      'stock_grade',
      'stock_grade',
      'system'
    )
  on conflict (category_id, slug) where category_id is not null
  do update set
    name = excluded.name,
    color = excluded.color,
    metadata = excluded.metadata,
    sort_order = excluded.sort_order,
    is_active = true;
end $$;
