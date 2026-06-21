begin;

-- =========================================================
-- Thrift currencies catalog
-- =========================================================

create table if not exists public.thrift_currencies (
  id bigserial primary key,
  name text not null,
  country text not null,
  code text not null unique,
  symbol text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_thrift_currencies_updated_at
before update on public.thrift_currencies
for each row execute function public.set_updated_at();

alter table public.thrift_currencies enable row level security;

create policy select_thrift_currencies on public.thrift_currencies
  for select to authenticated
  using (is_active = true);

grant select on table public.thrift_currencies to authenticated;
grant usage, select on sequence public.thrift_currencies_id_seq to authenticated;

insert into public.thrift_currencies (name, country, code, symbol)
values
  ('British Pound', 'United Kingdom', 'GBP', '£'),
  ('Bangladeshi Taka', 'Bangladesh', 'BDT', '৳')
on conflict (code) do update
set
  name = excluded.name,
  country = excluded.country,
  symbol = excluded.symbol,
  is_active = true;

-- =========================================================
-- Thrift settings: currency FKs + rename default price column
-- =========================================================

alter table public.thrift_settings
  rename column default_purchase_price_gbp to default_origin_purchase_price;

alter table public.thrift_settings
  add column if not exists default_purchase_currency_id bigint
    references public.thrift_currencies(id),
  add column if not exists default_sold_currency_id bigint
    references public.thrift_currencies(id);

update public.thrift_settings ts
set
  default_purchase_currency_id = coalesce(
    ts.default_purchase_currency_id,
    (select id from public.thrift_currencies where code = 'GBP')
  ),
  default_sold_currency_id = coalesce(
    ts.default_sold_currency_id,
    (select id from public.thrift_currencies where code = 'BDT')
  );

-- =========================================================
-- Stock + pricing expense columns
-- =========================================================

alter table public.thrift_stocks
  add column if not exists extra_origin_purchase_expense numeric(12, 2) null
    check (extra_origin_purchase_expense >= 0);

alter table public.thrift_pricings
  add column if not exists extra_expense_cost numeric(12, 2) not null default 0.00
    check (extra_expense_cost >= 0);

-- =========================================================
-- list_thrift_stocks_paginated
-- =========================================================

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

  select count(*)
  into v_total_count
  from public.thrift_stocks s
  where s.tenant_id = p_tenant_id
    and (v_status is null or s.status::text = v_status)
    and (v_condition is null or s.condition::text = v_condition)
    and (
      v_search is null
      or coalesce(s.name, '') ilike '%' || v_search || '%'
      or coalesce(s.brand_name, '') ilike '%' || v_search || '%'
      or coalesce(s.barcode, '') ilike '%' || v_search || '%'
    );

  select coalesce(jsonb_agg(row_data order by sort_created_at desc), '[]'::jsonb)
  into v_data
  from (
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
        'origin_purchase_price', s.origin_purchase_price,
        'extra_origin_purchase_expense', s.extra_origin_purchase_expense,
        'inserted_by', s.inserted_by,
        'created_at', s.created_at,
        'updated_at', s.updated_at,
        'pricing', coalesce((
          select jsonb_build_object(
            'cost_of_goods_sold', p.cost_of_goods_sold,
            'target_price', p.target_price,
            'listed_price', p.listed_price,
            'extra_expense_cost', p.extra_expense_cost
          )
          from public.thrift_pricings p
          where p.stock_id = s.id
          limit 1
        ), '{}'::jsonb),
        'image_url', (
          select i.image_url
          from public.thrift_stock_images i
          where i.stock_id = s.id
            and i.is_primary = true
          limit 1
        )
      ) as row_data,
      s.created_at as sort_created_at
    from public.thrift_stocks s
    where s.tenant_id = p_tenant_id
      and (v_status is null or s.status::text = v_status)
      and (v_condition is null or s.condition::text = v_condition)
      and (
        v_search is null
        or coalesce(s.name, '') ilike '%' || v_search || '%'
        or coalesce(s.brand_name, '') ilike '%' || v_search || '%'
        or coalesce(s.barcode, '') ilike '%' || v_search || '%'
      )
    order by s.created_at desc
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
      'total_pages', v_total_pages
    )
  );
end;
$$;

-- =========================================================
-- register_thrift_stock_from_app
-- =========================================================

drop function if exists public.register_thrift_stock_from_app(
  bigint, text, bigint, text, text, bigint, bigint, text, bigint, text, text, text,
  bigint, numeric, numeric, text, numeric, numeric, numeric, numeric, text
);

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
  p_extra_origin_purchase_expense numeric default null,
  p_cost_of_goods_sold numeric default 0,
  p_target_price numeric default 0,
  p_listed_price numeric default 0,
  p_extra_expense_cost numeric default 0,
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
      origin_purchase_price,
      extra_origin_purchase_expense
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
      p_origin_purchase_price,
      p_extra_origin_purchase_expense
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
      extra_origin_purchase_expense = p_extra_origin_purchase_expense,
      inserted_by = p_inserted_by
    where id = v_stock_id;
  end if;

  insert into public.thrift_pricings (
    stock_id,
    cost_of_goods_sold,
    target_price,
    listed_price,
    extra_expense_cost,
    inserted_by
  )
  values (
    v_stock_id,
    coalesce(p_cost_of_goods_sold, 0),
    coalesce(p_target_price, 0),
    coalesce(p_listed_price, 0),
    coalesce(p_extra_expense_cost, 0),
    p_inserted_by
  )
  on conflict (stock_id) do update
  set
    cost_of_goods_sold = excluded.cost_of_goods_sold,
    target_price = excluded.target_price,
    listed_price = excluded.listed_price,
    extra_expense_cost = excluded.extra_expense_cost,
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

grant execute on function public.register_thrift_stock_from_app(
  bigint, text, bigint, text, text, bigint, bigint, text, bigint, text, text, text,
  bigint, numeric, numeric, text, numeric, numeric, numeric, numeric, numeric, numeric, text
) to authenticated;

commit;
