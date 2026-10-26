-- Repair: 20271008130000 updated RPCs before the column existed on some DBs.

alter table public.shops
  add column if not exists display_quantity_add integer default 6 not null;

alter table public.shops
  drop constraint if exists shops_display_quantity_add_check;

alter table public.shops
  add constraint shops_display_quantity_add_check check (display_quantity_add >= 0);

create or replace function public.shop_padded_display_quantity(p_real integer, p_add integer default 6)
returns integer
language sql
immutable
set search_path to public
as $$
  select case
    when coalesce(p_real, 0) <= 0 then 0
    when p_real <= 2 then p_real
    else p_real + greatest(coalesce(p_add, 6), 0)
  end;
$$;

create or replace function public.recalc_shop_display_quantities(p_shop_id bigint)
returns integer
language plpgsql
security definer
set search_path to public
as $$
declare
  v_tenant_id bigint;
  v_display_add integer;
  v_updated integer;
begin
  if p_shop_id is null then
    raise exception 'shop required';
  end if;

  select s.tenant_id, coalesce(s.display_quantity_add, 6)
  into v_tenant_id, v_display_add
  from public.shops s
  where s.id = p_shop_id
    and s.deleted_at is null;

  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  with updated as (
    update public.shop_product_listings l
    set
      display_quantity_override = public.shop_padded_display_quantity(
        public.shop_product_grade_available_units(
          v_tenant_id,
          l.product_id,
          gs.grade_tag_id
        ),
        v_display_add
      ),
      updated_at = now()
    from public.global_stocks gs
    where l.shop_id = p_shop_id
      and l.global_stock_id = gs.id
      and not l.is_quantity_locked
    returning l.id
  )
  select count(*)::integer into v_updated from updated;

  return coalesce(v_updated, 0);
end;
$$;

grant execute on function public.shop_padded_display_quantity(integer, integer) to authenticated;
grant execute on function public.recalc_shop_display_quantities(bigint) to authenticated;
