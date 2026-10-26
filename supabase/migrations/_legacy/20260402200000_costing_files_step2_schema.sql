-- =========================================================
-- Step 2: Costing file backend schema
-- Create costing_files and costing_file_items with
-- enums, constraints, indexes, and normalization rules.
-- =========================================================

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typnamespace = 'public'::regnamespace
      and typname = 'costing_file_status'
  ) then
    create type public.costing_file_status as enum (
      'draft',
      'customer_submitted',
      'in_review',
      'priced',
      'offered',
      'completed',
      'cancelled'
    );
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typnamespace = 'public'::regnamespace
      and typname = 'costing_file_item_status'
  ) then
    create type public.costing_file_item_status as enum (
      'pending',
      'accepted',
      'rejected'
    );
  end if;
end
$$;

create or replace function public.normalize_costing_file_market()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.market := upper(trim(coalesce(new.market, '')));
  return new;
end;
$$;

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

  return new;
end;
$$;

create or replace function public.validate_costing_file_customer_group()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_group_tenant_id bigint;
begin
  select cg.tenant_id
  into v_group_tenant_id
  from public.customer_groups cg
  where cg.id = new.customer_group_id;

  if v_group_tenant_id is null then
    raise exception 'customer_group_id % does not exist', new.customer_group_id;
  end if;

  if v_group_tenant_id <> new.tenant_id then
    raise exception 'customer_group_id % does not belong to tenant_id %', new.customer_group_id, new.tenant_id;
  end if;

  return new;
end;
$$;

create table if not exists public.costing_files (
  id bigserial primary key,
  name text not null,
  cargo_rate_1kg numeric(12,2),
  cargo_rate_2kg numeric(12,2),
  conversion_rate numeric(12,2),
  admin_profit_rate numeric(12,2),
  status public.costing_file_status not null default 'draft',
  market text not null,
  customer_group_id bigint not null references public.customer_groups(id) on delete cascade,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  created_by_email text not null default public.current_user_email(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint costing_files_name_not_blank check (length(trim(name)) > 0),
  constraint costing_files_market_not_blank check (length(trim(market)) > 0),
  constraint costing_files_cargo_rate_1kg_nonnegative check (cargo_rate_1kg is null or cargo_rate_1kg >= 0),
  constraint costing_files_cargo_rate_2kg_nonnegative check (cargo_rate_2kg is null or cargo_rate_2kg >= 0),
  constraint costing_files_conversion_rate_nonnegative check (conversion_rate is null or conversion_rate >= 0),
  constraint costing_files_admin_profit_rate_nonnegative check (admin_profit_rate is null or admin_profit_rate >= 0)
);

create table if not exists public.costing_file_items (
  id bigserial primary key,
  costing_file_id bigint not null references public.costing_files(id) on delete cascade,
  name text,
  image_url text,
  website_url text not null,
  quantity integer not null,
  product_weight integer,
  package_weight integer,
  price_in_web_gbp numeric(12,2),
  delivery_price_gbp numeric(12,2),
  auxiliary_price_gbp numeric(12,2),
  item_price_gbp numeric(12,2),
  cargo_rate numeric(12,2),
  costing_price_gbp numeric(12,2),
  costing_price_bdt integer,
  offer_price_bdt integer,
  customer_profit_rate numeric(12,2),
  status public.costing_file_item_status not null default 'pending',
  created_by_email text not null default public.current_user_email(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint costing_file_items_website_url_not_blank check (length(trim(website_url)) > 0),
  constraint costing_file_items_quantity_positive check (quantity > 0),
  constraint costing_file_items_product_weight_nonnegative check (product_weight is null or product_weight >= 0),
  constraint costing_file_items_package_weight_nonnegative check (package_weight is null or package_weight >= 0),
  constraint costing_file_items_price_in_web_gbp_nonnegative check (price_in_web_gbp is null or price_in_web_gbp >= 0),
  constraint costing_file_items_delivery_price_gbp_nonnegative check (delivery_price_gbp is null or delivery_price_gbp >= 0),
  constraint costing_file_items_auxiliary_price_gbp_nonnegative check (auxiliary_price_gbp is null or auxiliary_price_gbp >= 0),
  constraint costing_file_items_item_price_gbp_nonnegative check (item_price_gbp is null or item_price_gbp >= 0),
  constraint costing_file_items_cargo_rate_nonnegative check (cargo_rate is null or cargo_rate >= 0),
  constraint costing_file_items_costing_price_gbp_nonnegative check (costing_price_gbp is null or costing_price_gbp >= 0),
  constraint costing_file_items_costing_price_bdt_nonnegative check (costing_price_bdt is null or costing_price_bdt >= 0),
  constraint costing_file_items_offer_price_bdt_nonnegative check (offer_price_bdt is null or offer_price_bdt >= 0),
  constraint costing_file_items_customer_profit_rate_nonnegative check (customer_profit_rate is null or customer_profit_rate >= 0)
);

create index if not exists costing_files_tenant_id_idx
  on public.costing_files (tenant_id);

create index if not exists costing_files_customer_group_id_idx
  on public.costing_files (customer_group_id);

create index if not exists costing_files_status_idx
  on public.costing_files (status);

create index if not exists costing_file_items_costing_file_id_idx
  on public.costing_file_items (costing_file_id);

create index if not exists costing_file_items_status_idx
  on public.costing_file_items (status);

drop trigger if exists trg_costing_files_updated_at on public.costing_files;
create trigger trg_costing_files_updated_at
before update on public.costing_files
for each row execute function public.set_updated_at();

drop trigger if exists trg_costing_file_items_updated_at on public.costing_file_items;
create trigger trg_costing_file_items_updated_at
before update on public.costing_file_items
for each row execute function public.set_updated_at();

drop trigger if exists trg_costing_files_normalize_market on public.costing_files;
create trigger trg_costing_files_normalize_market
before insert or update on public.costing_files
for each row execute function public.normalize_costing_file_market();

drop trigger if exists trg_costing_file_items_normalize_fields on public.costing_file_items;
create trigger trg_costing_file_items_normalize_fields
before insert or update on public.costing_file_items
for each row execute function public.normalize_costing_file_item_fields();

drop trigger if exists trg_costing_files_validate_customer_group on public.costing_files;
create trigger trg_costing_files_validate_customer_group
before insert or update on public.costing_files
for each row execute function public.validate_costing_file_customer_group();
