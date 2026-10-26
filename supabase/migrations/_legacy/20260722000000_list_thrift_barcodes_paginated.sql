-- Paginated thrift barcode list (sequence order) + canonical barcode resolve for mobile scan.
begin;

create or replace function public.thrift_barcode_sequence_sort_key(p_barcode_id text)
returns table (
  sort_prefix text,
  sort_year text,
  sort_seq integer
)
language sql
immutable
as $$
  select
    case
      when p_barcode_id ~ '^\d+-[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 2)
      when p_barcode_id ~ '^[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 1)
      else coalesce(p_barcode_id, '')
    end as sort_prefix,
    case
      when p_barcode_id ~ '^\d+-[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 3)
      when p_barcode_id ~ '^[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 2)
      else ''
    end as sort_year,
    case
      when p_barcode_id ~ '^\d+-[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 4)::integer
      when p_barcode_id ~ '^[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 3)::integer
      else 0
    end as sort_seq;
$$;

create or replace function public.resolve_thrift_barcode_id_internal(
  p_tenant_id bigint,
  p_scanned_value text
)
returns text
language plpgsql
stable
set search_path = public
as $$
declare
  v_raw text;
  v_candidates text[] := array[]::text[];
  v_match text;
  v_tenant_prefix text;
  v_compact text[];
begin
  v_raw := upper(trim(regexp_replace(coalesce(p_scanned_value, ''), '[^A-Za-z0-9-]', '', 'g')));
  if v_raw = '' then
    return null;
  end if;

  v_tenant_prefix := lpad(p_tenant_id::text, 2, '0');
  v_candidates := array_append(v_candidates, v_raw);

  -- 4-part with optional short sequence: 01-AA-26-1 -> 01-AA-26-000001
  if v_raw ~ '^\d+-[A-Z]{2}-\d{2}-\d+$' then
    v_candidates := array_append(v_candidates,
      split_part(v_raw, '-', 1) || '-' ||
      split_part(v_raw, '-', 2) || '-' ||
      split_part(v_raw, '-', 3) || '-' ||
      lpad(split_part(v_raw, '-', 4), 6, '0'));
  end if;

  -- Legacy 3-part -> inject tenant prefix
  if v_raw ~ '^[A-Z]{2}-\d{2}-\d+$' then
    v_candidates := array_append(v_candidates, v_tenant_prefix || '-' || v_raw);
    v_candidates := array_append(v_candidates,
      v_tenant_prefix || '-' ||
      split_part(v_raw, '-', 1) || '-' ||
      split_part(v_raw, '-', 2) || '-' ||
      lpad(split_part(v_raw, '-', 3), 6, '0'));
  end if;

  -- Hyphenless compact: 01AA26000001 or 100AA26000001
  if v_raw ~ '^\d+[A-Z]{2}\d{6,}$' then
    v_compact := regexp_match(v_raw, '^(\d+)([A-Z]{2})(\d{2})(\d+)$');
    if v_compact is not null then
      v_candidates := array_append(v_candidates,
        v_compact[1] || '-' || v_compact[2] || '-' || v_compact[3] || '-' || lpad(v_compact[4], 6, '0'));
    end if;
  end if;

  select b.barcode_id
  into v_match
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and b.barcode_id = any (v_candidates)
  order by b.barcode_id
  limit 1;

  return v_match;
end;
$$;

create or replace function public.resolve_thrift_barcode(
  p_tenant_id bigint,
  p_scanned_value text
)
returns table (barcode_id text, status text)
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_canonical text;
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

  v_canonical := public.resolve_thrift_barcode_id_internal(p_tenant_id, p_scanned_value);
  if v_canonical is null then
    return;
  end if;

  return query
  select b.barcode_id, b.status
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and b.barcode_id = v_canonical
  limit 1;
end;
$$;

create or replace function public.list_thrift_barcodes_paginated(
  p_tenant_id bigint,
  p_page integer default 1,
  p_page_size integer default 50,
  p_search text default null,
  p_is_printed smallint default null,
  p_status text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(coalesce(p_page_size, 50), 1);
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_status text := nullif(trim(coalesce(p_status, '')), '');
  v_unprinted_total bigint;
  v_available_total bigint;
  v_latest_current_year text;
  v_current_year text := to_char(now(), 'YY');
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

  select count(*)
  into v_total_count
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and (p_is_printed is null or b.is_printed = p_is_printed)
    and (v_status is null or b.status = v_status)
    and (
      v_search is null
      or coalesce(b.barcode_id, '') ilike '%' || v_search || '%'
      or coalesce(b.inserted_by, '') ilike '%' || v_search || '%'
    );

  select count(*)
  into v_unprinted_total
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and b.is_printed = 0;

  select count(*)
  into v_available_total
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and b.status = 'AVAILABLE';

  select b.barcode_id
  into v_latest_current_year
  from public.thrift_barcodes b
  cross join lateral public.thrift_barcode_sequence_sort_key(b.barcode_id) sk
  where b.tenant_id = p_tenant_id
    and b.barcode_id like '%-' || v_current_year || '-%'
  order by sk.sort_prefix desc, sk.sort_year desc, sk.sort_seq desc, b.barcode_id desc
  limit 1;

  select coalesce(jsonb_agg(row_data order by sort_prefix asc, sort_year asc, sort_seq asc, sort_barcode_id asc), '[]'::jsonb)
  into v_data
  from (
    select
      jsonb_build_object(
        'id', b.id,
        'tenant_id', b.tenant_id,
        'barcode_id', b.barcode_id,
        'status', b.status,
        'is_printed', b.is_printed,
        'inserted_by', b.inserted_by,
        'created_at', b.created_at,
        'updated_at', b.updated_at
      ) as row_data,
      sk.sort_prefix,
      sk.sort_year,
      sk.sort_seq,
      b.barcode_id as sort_barcode_id
    from public.thrift_barcodes b
    cross join lateral public.thrift_barcode_sequence_sort_key(b.barcode_id) sk
    where b.tenant_id = p_tenant_id
      and (p_is_printed is null or b.is_printed = p_is_printed)
      and (v_status is null or b.status = v_status)
      and (
        v_search is null
        or coalesce(b.barcode_id, '') ilike '%' || v_search || '%'
        or coalesce(b.inserted_by, '') ilike '%' || v_search || '%'
      )
    order by sk.sort_prefix asc, sk.sort_year asc, sk.sort_seq asc, b.barcode_id asc
    offset (v_page - 1) * v_page_size
    limit v_page_size
  ) paged;

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
      'total_pages', v_total_pages,
      'unprinted_total', v_unprinted_total,
      'available_total', v_available_total,
      'latest_current_year_barcode_id', v_latest_current_year
    )
  );
end;
$$;

create or replace function public.register_thrift_stock_from_app(
  p_tenant_id bigint,
  p_barcode text,
  p_shipment_id bigint,
  p_image_url text,
  p_brand_name text default null,
  p_category_id bigint default null,
  p_type_id bigint default null,
  p_section text default null,
  p_shelf_id bigint default null,
  p_color text default null,
  p_size text default null,
  p_condition text default null,
  p_box_id bigint default null,
  p_product_weight numeric default null,
  p_extra_weight numeric default null,
  p_note text default null,
  p_origin_purchase_price numeric default null,
  p_cost_of_goods_sold numeric default 0,
  p_target_price numeric default 0,
  p_listed_price numeric default 0,
  p_inserted_by text default 'app-user'
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_barcode_row public.thrift_barcodes%rowtype;
  v_stock_id bigint;
  v_section public.thrift_section;
  v_condition public.thrift_condition;
  v_canonical_barcode text;
begin
  if trim(coalesce(p_barcode, '')) = '' then
    raise exception 'Barcode is required';
  end if;

  if trim(coalesce(p_image_url, '')) = '' then
    raise exception 'Image URL is required';
  end if;

  v_section := nullif(trim(coalesce(p_section, '')), '')::public.thrift_section;
  v_condition := nullif(trim(coalesce(p_condition, '')), '')::public.thrift_condition;

  if not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  ) then
    raise exception 'Not authorized for this tenant';
  end if;

  v_canonical_barcode := public.resolve_thrift_barcode_id_internal(p_tenant_id, p_barcode);
  if v_canonical_barcode is null then
    raise exception 'Barcode not found in catalog';
  end if;

  select *
  into v_barcode_row
  from public.thrift_barcodes
  where tenant_id = p_tenant_id
    and barcode_id = v_canonical_barcode
  for update;

  if not found then
    raise exception 'Barcode not found in catalog';
  end if;

  select id
  into v_stock_id
  from public.thrift_stocks
  where tenant_id = p_tenant_id
    and barcode = v_canonical_barcode
  limit 1;

  if v_stock_id is null then
    if v_barcode_row.status <> 'AVAILABLE' then
      raise exception 'Barcode is already used';
    end if;

    insert into public.thrift_stocks (
      tenant_id,
      shipment_id,
      brand_name,
      category_id,
      type_id,
      section,
      shelf_id,
      color,
      size,
      condition,
      barcode,
      stock_type,
      quantity,
      box_id,
      product_weight,
      extra_weight,
      status,
      note,
      inserted_by,
      origin_purchase_price
    )
    values (
      p_tenant_id,
      p_shipment_id,
      nullif(trim(coalesce(p_brand_name, '')), ''),
      p_category_id,
      p_type_id,
      v_section,
      p_shelf_id,
      nullif(trim(coalesce(p_color, '')), ''),
      nullif(trim(coalesce(p_size, '')), ''),
      v_condition,
      v_canonical_barcode,
      'SINGLE',
      1,
      p_box_id,
      p_product_weight,
      p_extra_weight,
      'AVAILABLE',
      coalesce(p_note, ''),
      p_inserted_by,
      p_origin_purchase_price
    )
    returning id into v_stock_id;
  else
    update public.thrift_stocks
    set
      shipment_id = p_shipment_id,
      brand_name = nullif(trim(coalesce(p_brand_name, '')), ''),
      category_id = p_category_id,
      type_id = p_type_id,
      section = v_section,
      shelf_id = p_shelf_id,
      color = nullif(trim(coalesce(p_color, '')), ''),
      size = nullif(trim(coalesce(p_size, '')), ''),
      condition = v_condition,
      box_id = p_box_id,
      product_weight = p_product_weight,
      extra_weight = p_extra_weight,
      note = coalesce(p_note, ''),
      origin_purchase_price = p_origin_purchase_price,
      inserted_by = p_inserted_by
    where id = v_stock_id;
  end if;

  insert into public.thrift_pricings (
    stock_id,
    cost_of_goods_sold,
    target_price,
    listed_price,
    inserted_by
  )
  values (
    v_stock_id,
    coalesce(p_cost_of_goods_sold, 0),
    coalesce(p_target_price, 0),
    coalesce(p_listed_price, 0),
    p_inserted_by
  )
  on conflict (stock_id) do update
  set
    cost_of_goods_sold = excluded.cost_of_goods_sold,
    target_price = excluded.target_price,
    listed_price = excluded.listed_price,
    inserted_by = excluded.inserted_by;

  update public.thrift_stock_images
  set image_url = p_image_url,
      inserted_by = p_inserted_by
  where stock_id = v_stock_id
    and is_primary = true;

  if not found then
    insert into public.thrift_stock_images (
      stock_id,
      image_url,
      is_primary,
      inserted_by
    )
    values (
      v_stock_id,
      p_image_url,
      true,
      p_inserted_by
    );
  end if;

  update public.thrift_barcodes
  set status = 'USED'
  where tenant_id = p_tenant_id
    and barcode_id = v_canonical_barcode;

  return v_stock_id;
end;
$$;

grant execute on function public.list_thrift_barcodes_paginated(
  bigint, integer, integer, text, smallint, text
) to authenticated;

grant execute on function public.resolve_thrift_barcode(
  bigint, text
) to authenticated;

grant execute on function public.register_thrift_stock_from_app(
  bigint, text, bigint, text, text, bigint, bigint, text, bigint, text, text, text,
  bigint, numeric, numeric, text, numeric, numeric, numeric, numeric, text
) to authenticated;

commit;
