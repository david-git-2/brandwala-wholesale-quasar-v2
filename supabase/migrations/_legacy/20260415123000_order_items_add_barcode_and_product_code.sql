begin;

alter table public.order_items
  add column if not exists barcode text null,
  add column if not exists product_code text null;

create index if not exists order_items_barcode_idx
  on public.order_items using btree (barcode);

create index if not exists order_items_product_code_idx
  on public.order_items using btree (product_code);

create or replace function public.set_order_item_product_identity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product record;
begin
  if new.product_id is null then
    return new;
  end if;

  select p.barcode, p.product_code
  into v_product
  from public.products p
  where p.id = new.product_id;

  if found then
    new.barcode := coalesce(new.barcode, v_product.barcode);
    new.product_code := coalesce(new.product_code, v_product.product_code);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_order_items_set_product_identity on public.order_items;
create trigger trg_order_items_set_product_identity
before insert or update of product_id on public.order_items
for each row
execute function public.set_order_item_product_identity();

update public.order_items oi
set
  barcode = coalesce(oi.barcode, p.barcode),
  product_code = coalesce(oi.product_code, p.product_code)
from public.products p
where p.id = oi.product_id
  and (oi.barcode is null or oi.product_code is null);

commit;
