-- SQL Migration: 20261130000016_add_default_add_quantity_to_shop_pricing_rules.sql
-- Description: Add default_add_quantity column to shop_pricing_rules table and update upsert_shop_pricing_rule RPC

begin;

-- 1. Add default_add_quantity column
alter table public.shop_pricing_rules
  add column if not exists default_add_quantity integer not null default 0;

-- 2. Update upsert_shop_pricing_rule RPC signature and body
create or replace function public.upsert_shop_pricing_rule(
  p_shop_id bigint,
  p_markup_percentage numeric,
  p_is_auto_publish boolean,
  p_default_show_quantity boolean default true,
  p_default_add_quantity integer default 0
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
    default_add_quantity
  )
  values (
    v_tenant_id,
    p_shop_id,
    p_markup_percentage,
    p_is_auto_publish,
    coalesce(p_default_show_quantity, true),
    coalesce(p_default_add_quantity, 0)
  )
  on conflict (shop_id) do update set
    markup_percentage = excluded.markup_percentage,
    is_auto_publish = excluded.is_auto_publish,
    default_show_quantity = excluded.default_show_quantity,
    default_add_quantity = excluded.default_add_quantity,
    updated_at = now()
  returning *;
end;
$$;

grant execute on function public.upsert_shop_pricing_rule(bigint, numeric, boolean, boolean, integer) to authenticated;

commit;
