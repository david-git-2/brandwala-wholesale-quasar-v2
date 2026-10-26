-- Write demand rows when a catalog order or PBC file enters procuring.

create or replace function public.ensure_preorder_demand_for_procuring_document(
  p_document_type text,
  p_document_id bigint
) returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
begin
  if p_document_id is null then
    return;
  end if;

  if v_doc_type = 'shop_order' then
    insert into public.preorder_demand (
      tenant_id,
      source_type,
      source_id,
      profile_id,
      placed_quantity,
      delivered_quantity,
      stock_picks
    )
    select
      o.tenant_id,
      'shop_order_item'::public.preorder_demand_source_type,
      oi.id,
      o.profile_id,
      0,
      0,
      '[]'::jsonb
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    where o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog'
    on conflict (source_type, source_id) do update set
      profile_id = coalesce(public.preorder_demand.profile_id, excluded.profile_id),
      updated_at = now();
  elsif v_doc_type = 'pbc_costing_file' then
    insert into public.preorder_demand (
      tenant_id,
      source_type,
      source_id,
      profile_id,
      placed_quantity,
      delivered_quantity,
      stock_picks
    )
    select
      f.tenant_id,
      'pbc_costing_item'::public.preorder_demand_source_type,
      pci.id,
      f.profile_id,
      0,
      0,
      '[]'::jsonb
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    where f.id = p_document_id
    on conflict (source_type, source_id) do update set
      profile_id = coalesce(public.preorder_demand.profile_id, excluded.profile_id),
      updated_at = now();
  end if;
end;
$$;

revoke all on function public.ensure_preorder_demand_for_procuring_document(text, bigint) from public;
revoke all on function public.ensure_preorder_demand_for_procuring_document(text, bigint) from anon;
revoke all on function public.ensure_preorder_demand_for_procuring_document(text, bigint) from authenticated;

create or replace function public.trg_fn_shop_order_write_preorder_demand()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if NEW.shop_type_snapshot = 'vendor_catalog'
    and NEW.status = 'procuring'::public.shop_order_status
    and OLD.status is distinct from NEW.status then
    perform public.ensure_preorder_demand_for_procuring_document('shop_order', NEW.id);
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_shop_order_write_preorder_demand on public.shop_orders;
create trigger trg_shop_order_write_preorder_demand
after update on public.shop_orders
for each row execute function public.trg_fn_shop_order_write_preorder_demand();

create or replace function public.trg_fn_pbc_file_write_preorder_demand()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if public.normalize_pbc_procurement_status(NEW.status) = 'procuring'
    and public.normalize_pbc_procurement_status(OLD.status) is distinct from 'procuring' then
    perform public.ensure_preorder_demand_for_procuring_document('pbc_costing_file', NEW.id);
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_pbc_file_write_preorder_demand on public.product_based_costing_files;
create trigger trg_pbc_file_write_preorder_demand
after update on public.product_based_costing_files
for each row execute function public.trg_fn_pbc_file_write_preorder_demand();

revoke all on function public.trg_fn_shop_order_write_preorder_demand() from public;
revoke all on function public.trg_fn_pbc_file_write_preorder_demand() from public;

do $$
declare
  r record;
begin
  for r in
    select o.id
    from public.shop_orders o
    where o.shop_type_snapshot = 'vendor_catalog'
      and o.status = 'procuring'::public.shop_order_status
  loop
    perform public.ensure_preorder_demand_for_procuring_document('shop_order', r.id);
  end loop;

  for r in
    select f.id
    from public.product_based_costing_files f
    where public.normalize_pbc_procurement_status(f.status) = 'procuring'
  loop
    perform public.ensure_preorder_demand_for_procuring_document('pbc_costing_file', r.id);
  end loop;
end;
$$;
