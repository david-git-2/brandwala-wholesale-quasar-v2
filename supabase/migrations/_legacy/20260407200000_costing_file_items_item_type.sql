-- =========================================================
-- Add a free-text item type field to costing_file_items.
-- This supports values like watch, perfume, and others.
-- =========================================================

alter table public.costing_file_items
  add column if not exists item_type text;

alter table public.costing_file_items
  drop constraint if exists costing_file_items_item_type_not_blank;

alter table public.costing_file_items
  add constraint costing_file_items_item_type_not_blank
  check (item_type is null or length(trim(item_type)) > 0);

create or replace function public.normalize_costing_file_item_fields()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.website_url := trim(coalesce(new.website_url, ''));

  if new.image_url is not null then
    new.image_url := nullif(trim(new.image_url), '');
  end if;

  if new.name is not null then
    new.name := nullif(trim(new.name), '');
  end if;

  if new.item_type is not null then
    new.item_type := nullif(trim(new.item_type), '');
  end if;

  if new.size is not null then
    new.size := nullif(trim(new.size), '');
  end if;

  if new.color is not null then
    new.color := nullif(trim(new.color), '');
  end if;

  if new.extra_information_1 is not null then
    new.extra_information_1 := nullif(trim(new.extra_information_1), '');
  end if;

  if new.extra_information_2 is not null then
    new.extra_information_2 := nullif(trim(new.extra_information_2), '');
  end if;

  return new;
end;
$$;

drop function if exists public.list_costing_file_items(bigint);

create or replace function public.list_costing_file_items(
  p_costing_file_id bigint
)
returns table(
  id bigint,
  costing_file_id bigint,
  name text,
  item_type text,
  image_url text,
  website_url text,
  quantity integer,
  product_weight integer,
  package_weight integer,
  price_in_web_gbp numeric,
  delivery_price_gbp numeric,
  auxiliary_price_gbp numeric,
  item_price_gbp numeric,
  cargo_rate numeric,
  costing_price_gbp numeric,
  costing_price_bdt integer,
  offer_price_override_bdt integer,
  offer_price_bdt integer,
  customer_profit_rate numeric,
  status public.costing_file_item_status,
  created_by_email text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    cfi.id,
    cfi.costing_file_id,
    cfi.name,
    cfi.item_type,
    cfi.image_url,
    cfi.website_url,
    cfi.quantity,
    cfi.product_weight,
    cfi.package_weight,
    cfi.price_in_web_gbp,
    cfi.delivery_price_gbp,
    cfi.auxiliary_price_gbp,
    cfi.item_price_gbp,
    cfi.cargo_rate,
    cfi.costing_price_gbp,
    cfi.costing_price_bdt,
    cfi.offer_price_override_bdt,
    cfi.offer_price_bdt,
    cfi.customer_profit_rate,
    cfi.status,
    cfi.created_by_email,
    cfi.created_at,
    cfi.updated_at
  from public.costing_file_items cfi
  where cfi.costing_file_id = p_costing_file_id
    and public.can_view_costing_file(cfi.costing_file_id)
  order by cfi.id asc;
$$;

grant execute on function public.list_costing_file_items(bigint)
to authenticated;

create or replace function public.update_costing_file_item_enrichment(
  p_id bigint,
  p_name text default null,
  p_item_type text default null,
  p_image_url text default null,
  p_product_weight integer default null,
  p_package_weight integer default null,
  p_price_in_web_gbp numeric default null,
  p_delivery_price_gbp numeric default null
)
returns table(
  id bigint,
  costing_file_id bigint,
  name text,
  item_type text,
  image_url text,
  product_weight integer,
  package_weight integer,
  price_in_web_gbp numeric,
  delivery_price_gbp numeric,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with updated as (
    update public.costing_file_items cfi
    set
      name = coalesce(trim(p_name), cfi.name),
      item_type = case
        when p_item_type is null then null
        else nullif(trim(p_item_type), '')
      end,
      image_url = coalesce(trim(p_image_url), cfi.image_url),
      product_weight = coalesce(p_product_weight, cfi.product_weight),
      package_weight = coalesce(p_package_weight, cfi.package_weight),
      price_in_web_gbp = coalesce(p_price_in_web_gbp, cfi.price_in_web_gbp),
      delivery_price_gbp = coalesce(p_delivery_price_gbp, cfi.delivery_price_gbp)
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
      )
    returning
      cfi.id,
      cfi.costing_file_id,
      cfi.name,
      cfi.item_type,
      cfi.image_url,
      cfi.product_weight,
      cfi.package_weight,
      cfi.price_in_web_gbp,
      cfi.delivery_price_gbp,
      cfi.updated_at
  )
  select *
  from updated;
$$;

grant execute on function public.update_costing_file_item_enrichment(bigint, text, text, text, integer, integer, numeric, numeric)
to authenticated;
