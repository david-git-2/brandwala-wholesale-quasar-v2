-- =========================================================
-- Step 6: Costing file calculation data flow
-- Add override support and connect stored calculation fields
-- to backend triggers and helper functions.
-- =========================================================

alter table public.costing_file_items
  add column if not exists offer_price_override_bdt integer;

alter table public.costing_file_items
  drop constraint if exists costing_file_items_offer_price_override_bdt_nonnegative;

alter table public.costing_file_items
  add constraint costing_file_items_offer_price_override_bdt_nonnegative
  check (offer_price_override_bdt is null or offer_price_override_bdt >= 0);

create or replace function public.round_bdt_up_to_zero_or_five(
  p_value numeric
)
returns integer
language plpgsql
immutable
as $$
declare
  v_rounded_up integer;
  v_remainder integer;
begin
  v_rounded_up := ceil(coalesce(p_value, 0))::integer;
  v_remainder := mod(v_rounded_up, 5);

  if v_remainder = 0 then
    return v_rounded_up;
  end if;

  return v_rounded_up + (5 - v_remainder);
end;
$$;

create or replace function public.calculate_costing_auxiliary_price_gbp(
  p_price_in_web_gbp numeric,
  p_delivery_price_gbp numeric
)
returns numeric
language plpgsql
immutable
as $$
declare
  v_base_price_gbp numeric(12,2);
begin
  v_base_price_gbp := round((coalesce(p_price_in_web_gbp, 0) + coalesce(p_delivery_price_gbp, 0))::numeric, 2);

  if v_base_price_gbp <= 10 then
    return 0;
  end if;

  if v_base_price_gbp <= 100 then
    return 2;
  end if;

  return round((2 + ceil((v_base_price_gbp - 100) / 50.0))::numeric, 2);
end;
$$;

create or replace function public.apply_costing_item_calculations()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cargo_rate_1kg numeric(12,2);
  v_cargo_rate_2kg numeric(12,2);
  v_conversion_rate numeric(12,2);
  v_admin_profit_rate numeric(12,2);
  v_total_weight integer;
  v_auxiliary_price_gbp numeric(12,2);
  v_item_price_gbp numeric(12,2);
  v_cargo_rate numeric(12,2);
  v_costing_price_gbp numeric(12,2);
  v_costing_price_bdt integer;
  v_calculated_offer_price_bdt integer;
begin
  select
    cf.cargo_rate_1kg,
    cf.cargo_rate_2kg,
    cf.conversion_rate,
    cf.admin_profit_rate
  into
    v_cargo_rate_1kg,
    v_cargo_rate_2kg,
    v_conversion_rate,
    v_admin_profit_rate
  from public.costing_files cf
  where cf.id = new.costing_file_id;

  v_total_weight := coalesce(new.product_weight, 0) + coalesce(new.package_weight, 0);
  v_auxiliary_price_gbp := public.calculate_costing_auxiliary_price_gbp(
    new.price_in_web_gbp,
    new.delivery_price_gbp
  )::numeric(12,2);

  v_item_price_gbp := round(
    (
      coalesce(new.price_in_web_gbp, 0)
      + coalesce(new.delivery_price_gbp, 0)
      + coalesce(v_auxiliary_price_gbp, 0)
    )::numeric,
    2
  );

  if v_item_price_gbp > 10 then
    v_cargo_rate := coalesce(v_cargo_rate_2kg, 0);
  else
    v_cargo_rate := coalesce(v_cargo_rate_1kg, 0);
  end if;

  v_cargo_rate := round(v_cargo_rate::numeric, 2);

  v_costing_price_gbp := round(
    (
      coalesce(v_item_price_gbp, 0)
      + (coalesce(v_total_weight, 0) / 1000.0) * coalesce(v_cargo_rate, 0)
    )::numeric,
    2
  );

  v_costing_price_bdt := public.round_bdt_up_to_zero_or_five(
    coalesce(v_costing_price_gbp, 0) * coalesce(v_conversion_rate, 0)
  );

  v_calculated_offer_price_bdt := public.round_bdt_up_to_zero_or_five(
    v_costing_price_bdt + (v_costing_price_bdt * coalesce(v_admin_profit_rate, 0) / 100.0)
  );

  new.auxiliary_price_gbp := v_auxiliary_price_gbp;
  new.item_price_gbp := v_item_price_gbp;
  new.cargo_rate := v_cargo_rate;
  new.costing_price_gbp := v_costing_price_gbp;
  new.costing_price_bdt := v_costing_price_bdt;
  new.offer_price_bdt := coalesce(new.offer_price_override_bdt, v_calculated_offer_price_bdt);

  return new;
end;
$$;

create or replace function public.refresh_costing_file_item_calculations_for_file()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if
    new.cargo_rate_1kg is distinct from old.cargo_rate_1kg
    or new.cargo_rate_2kg is distinct from old.cargo_rate_2kg
    or new.conversion_rate is distinct from old.conversion_rate
    or new.admin_profit_rate is distinct from old.admin_profit_rate
  then
    update public.costing_file_items cfi
    set updated_at = now()
    where cfi.costing_file_id = new.id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_costing_file_items_apply_calculations on public.costing_file_items;
create trigger trg_costing_file_items_apply_calculations
before insert or update on public.costing_file_items
for each row execute function public.apply_costing_item_calculations();

drop trigger if exists trg_costing_files_refresh_item_calculations on public.costing_files;
create trigger trg_costing_files_refresh_item_calculations
after update on public.costing_files
for each row execute function public.refresh_costing_file_item_calculations_for_file();

update public.costing_file_items cfi
set updated_at = now();

drop function if exists public.list_costing_file_items(bigint);

create or replace function public.list_costing_file_items(
  p_costing_file_id bigint
)
returns table(
  id bigint,
  costing_file_id bigint,
  name text,
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

drop function if exists public.update_costing_file_item_offer(bigint, numeric, numeric, numeric, numeric, integer, integer);

create or replace function public.update_costing_file_item_offer(
  p_id bigint,
  p_auxiliary_price_gbp numeric default null,
  p_item_price_gbp numeric default null,
  p_cargo_rate numeric default null,
  p_costing_price_gbp numeric default null,
  p_costing_price_bdt integer default null,
  p_offer_price_override_bdt integer default null
)
returns table(
  id bigint,
  auxiliary_price_gbp numeric,
  item_price_gbp numeric,
  cargo_rate numeric,
  costing_price_gbp numeric,
  costing_price_bdt integer,
  offer_price_override_bdt integer,
  offer_price_bdt integer,
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
      auxiliary_price_gbp = coalesce(p_auxiliary_price_gbp, cfi.auxiliary_price_gbp),
      item_price_gbp = coalesce(p_item_price_gbp, cfi.item_price_gbp),
      cargo_rate = coalesce(p_cargo_rate, cfi.cargo_rate),
      costing_price_gbp = coalesce(p_costing_price_gbp, cfi.costing_price_gbp),
      costing_price_bdt = coalesce(p_costing_price_bdt, cfi.costing_price_bdt),
      offer_price_override_bdt = p_offer_price_override_bdt
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.id = p_id
      and public.can_admin_manage_costing_file(cf.tenant_id)
    returning
      cfi.id,
      cfi.auxiliary_price_gbp,
      cfi.item_price_gbp,
      cfi.cargo_rate,
      cfi.costing_price_gbp,
      cfi.costing_price_bdt,
      cfi.offer_price_override_bdt,
      cfi.offer_price_bdt,
      cfi.updated_at
  )
  select *
  from updated;
$$;

grant execute on function public.update_costing_file_item_offer(bigint, numeric, numeric, numeric, numeric, integer, integer)
to authenticated;
