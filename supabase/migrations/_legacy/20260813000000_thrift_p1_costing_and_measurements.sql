-- Thrift P1 costing and measurements migration
begin;

-- 1) Backups (_bak_*)
create table if not exists public._bak_thrift_shipments as select * from public.thrift_shipments;
create table if not exists public._bak_thrift_stocks as select * from public.thrift_stocks;
create table if not exists public._bak_thrift_pricings as select * from public.thrift_pricings;
create table if not exists public._bak_thrift_settings as select * from public.thrift_settings;
create table if not exists public._bak_thrift_stock_images as select * from public.thrift_stock_images;

-- 2) Costing alters
alter table public.thrift_shipments
  add column if not exists total_cargo_weight_kg numeric null,
  add column if not exists labor_total_cost numeric null,
  add column if not exists transportation_total_cost numeric null,
  add column if not exists default_markup_rate numeric null;

alter table public.thrift_stocks
  rename column origin_purchase_price to origin_unit_price;
alter table public.thrift_stocks
  rename column extra_origin_purchase_expense to extra_origin_unit_price;
alter table public.thrift_stocks
  add column if not exists additional_charges_cost numeric null;

alter table public.thrift_pricings
  rename column listed_price to listed_unit_price;
alter table public.thrift_pricings
  add column if not exists is_listed_price_manual boolean default false;

alter table public.thrift_settings
  rename column default_origin_purchase_price to default_origin_unit_price;
alter table public.thrift_settings
  add column if not exists hand_tag_unit_cost numeric null,
  add column if not exists hand_tag_unit_currency_id bigint references public.global_currencies(id) on delete set null,
  add column if not exists sticker_unit_cost numeric null,
  add column if not exists sticker_unit_currency_id bigint references public.global_currencies(id) on delete set null;

-- 3) Create thrift_stock_measurements + RLS
create table if not exists public.thrift_stock_measurements (
  stock_id bigint primary key references public.thrift_stocks(id) on delete cascade,
  tenant_id bigint not null,
  bust_in numeric(5,1) null,
  waist_in numeric(5,1) null,
  hips_in numeric(5,1) null,
  length_in numeric(5,1) null,
  shoulder_width_in numeric(5,1) null,
  sleeve_length_in numeric(5,1) null,
  arm_circumference_in numeric(5,1) null,
  hem_width_in numeric(5,1) null,
  neck_opening_in numeric(5,1) null,
  sleeve_type text null,
  neckline text null,
  dress_style text null,
  fabric_stretch text null,
  lining boolean null,
  closure_type text null,
  measurement_notes text null,
  inserted_by text not null default 'system',
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now())
);

drop trigger if exists trg_thrift_stock_measurements_updated_at on public.thrift_stock_measurements;
create trigger trg_thrift_stock_measurements_updated_at
before update on public.thrift_stock_measurements
for each row execute function public.set_updated_at();

create index if not exists idx_thrift_stock_measurements_bust on public.thrift_stock_measurements(tenant_id, bust_in);
create index if not exists idx_thrift_stock_measurements_waist on public.thrift_stock_measurements(tenant_id, waist_in);
create index if not exists idx_thrift_stock_measurements_hips on public.thrift_stock_measurements(tenant_id, hips_in);

alter table public.thrift_stock_measurements enable row level security;

drop policy if exists select_thrift_stock_measurements on public.thrift_stock_measurements;
create policy select_thrift_stock_measurements on public.thrift_stock_measurements for select to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_stock_measurements.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true));

drop policy if exists write_thrift_stock_measurements on public.thrift_stock_measurements;
create policy write_thrift_stock_measurements on public.thrift_stock_measurements for all to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_stock_measurements.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true and m.role in ('admin', 'staff')));

grant select, insert, update, delete on table public.thrift_stock_measurements to authenticated;

-- 4) Recreate list_thrift_stocks_paginated
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

-- 5) Recreate register_thrift_stock_from_app with backward compatibility
create or replace function public.register_thrift_stock_from_app(
  p_tenant_id bigint,
  p_barcode text,
  p_shipment_id bigint,
  p_image_url text,
  p_brand_name text,
  p_category_id bigint,
  p_type_id bigint,
  p_section text,
  p_shelf_id bigint,
  p_color text,
  p_size text,
  p_condition text,
  p_box_id bigint default null,
  p_product_weight numeric default null,
  p_extra_weight numeric default null,
  p_note text default null,
  p_origin_purchase_price numeric default null,
  p_cost_of_goods_sold numeric default 0,
  p_target_price numeric default 0,
  p_listed_price numeric default 0,
  p_inserted_by text default 'app-user',
  p_origin_unit_price numeric default null,
  p_extra_origin_unit_price numeric default null,
  p_listed_unit_price numeric default null
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_barcode_row public.thrift_barcodes%rowtype;
  v_stock_id bigint;
  v_origin_unit_price numeric := coalesce(p_origin_unit_price, p_origin_purchase_price);
  v_extra_origin_unit_price numeric := coalesce(p_extra_origin_unit_price, 0);
  v_listed_unit_price numeric := coalesce(p_listed_unit_price, p_listed_price);
begin
  if trim(coalesce(p_barcode, '')) = '' then
    raise exception 'Barcode is required';
  end if;

  if trim(coalesce(p_image_url, '')) = '' then
    raise exception 'Image URL is required';
  end if;

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

  select *
  into v_barcode_row
  from public.thrift_barcodes
  where tenant_id = p_tenant_id
    and barcode_id = trim(p_barcode)
  for update;

  if not found then
    raise exception 'Barcode not found in catalog';
  end if;

  select id
  into v_stock_id
  from public.thrift_stocks
  where tenant_id = p_tenant_id
    and barcode = trim(p_barcode)
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
      origin_unit_price,
      extra_origin_unit_price
    )
    values (
      p_tenant_id,
      p_shipment_id,
      coalesce(p_brand_name, ''),
      p_category_id,
      p_type_id,
      p_section::public.thrift_section,
      p_shelf_id,
      p_color,
      p_size,
      p_condition::public.thrift_condition,
      trim(p_barcode),
      'SINGLE',
      1,
      p_box_id,
      p_product_weight,
      p_extra_weight,
      'AVAILABLE',
      coalesce(p_note, ''),
      p_inserted_by,
      v_origin_unit_price,
      v_extra_origin_unit_price
    )
    returning id into v_stock_id;
  else
    update public.thrift_stocks
    set
      shipment_id = p_shipment_id,
      brand_name = coalesce(p_brand_name, ''),
      category_id = p_category_id,
      type_id = p_type_id,
      section = p_section::public.thrift_section,
      shelf_id = p_shelf_id,
      color = p_color,
      size = p_size,
      condition = p_condition::public.thrift_condition,
      box_id = p_box_id,
      product_weight = p_product_weight,
      extra_weight = p_extra_weight,
      note = coalesce(p_note, ''),
      origin_unit_price = v_origin_unit_price,
      extra_origin_unit_price = v_extra_origin_unit_price,
      inserted_by = p_inserted_by
    where id = v_stock_id;
  end if;

  insert into public.thrift_pricings (
    stock_id,
    cost_of_goods_sold,
    target_price,
    listed_unit_price,
    inserted_by
  )
  values (
    v_stock_id,
    coalesce(p_cost_of_goods_sold, 0),
    coalesce(p_target_price, 0),
    coalesce(v_listed_unit_price, 0),
    p_inserted_by
  )
  on conflict (stock_id) do update
  set
    cost_of_goods_sold = excluded.cost_of_goods_sold,
    target_price = excluded.target_price,
    listed_unit_price = excluded.listed_unit_price,
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
    and barcode_id = trim(p_barcode);

  return v_stock_id;
end;
$$;

grant execute on function public.register_thrift_stock_from_app(
  bigint, text, bigint, text, text, bigint, bigint, text, bigint, text, text, text,
  bigint, numeric, numeric, text, numeric, numeric, numeric, numeric, text, numeric, numeric, numeric
) to authenticated;

commit;
