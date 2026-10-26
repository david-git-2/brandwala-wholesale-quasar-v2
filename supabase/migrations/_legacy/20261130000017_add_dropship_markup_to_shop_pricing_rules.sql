-- SQL Migration: 20261130000017_add_dropship_markup_to_shop_pricing_rules.sql
-- Description: Persist dropship floor markup percentage on shop_pricing_rules

begin;

alter table public.shop_pricing_rules
  add column if not exists dropship_markup_percentage numeric(8,2) not null default 0.00;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'shop_pricing_rules_dropship_markup_non_negative'
  ) then
    alter table public.shop_pricing_rules
      add constraint shop_pricing_rules_dropship_markup_non_negative
      check (dropship_markup_percentage >= 0);
  end if;
end;
$$;

create or replace function public.upsert_shop_pricing_rule(
  p_shop_id bigint,
  p_markup_percentage numeric,
  p_is_auto_publish boolean,
  p_default_show_quantity boolean default true,
  p_default_add_quantity integer default 0,
  p_dropship_markup_percentage numeric default 0
)
returns setof public.shop_pricing_rules
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id;
  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  insert into public.shop_pricing_rules (
    tenant_id,
    shop_id,
    markup_percentage,
    is_auto_publish,
    default_show_quantity,
    default_add_quantity,
    dropship_markup_percentage
  )
  values (
    v_tenant_id,
    p_shop_id,
    p_markup_percentage,
    p_is_auto_publish,
    coalesce(p_default_show_quantity, true),
    coalesce(p_default_add_quantity, 0),
    coalesce(p_dropship_markup_percentage, 0)
  )
  on conflict (shop_id) do update set
    markup_percentage = excluded.markup_percentage,
    is_auto_publish = excluded.is_auto_publish,
    default_show_quantity = excluded.default_show_quantity,
    default_add_quantity = excluded.default_add_quantity,
    dropship_markup_percentage = excluded.dropship_markup_percentage,
    updated_at = now()
  returning *;
end;
$$;

grant execute on function public.upsert_shop_pricing_rule(bigint, numeric, boolean, boolean, integer, numeric) to authenticated;

commit;
