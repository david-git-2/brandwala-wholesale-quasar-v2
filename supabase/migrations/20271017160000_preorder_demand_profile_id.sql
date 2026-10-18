-- Stamp customer profile on demand / delivery-paper rows for leftover queries.

alter table public.preorder_demand
  add column if not exists profile_id bigint;

alter table public.preorder_demand
  drop constraint if exists preorder_demand_profile_id_fkey;

alter table public.preorder_demand
  add constraint preorder_demand_profile_id_fkey
  foreign key (profile_id) references public.profiles(id) on delete set null;

create index if not exists preorder_demand_tenant_profile_idx
  on public.preorder_demand using btree (tenant_id, profile_id)
  where profile_id is not null;

create or replace function public.trg_fn_preorder_demand_stamp_profile()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
  if NEW.profile_id is not null then
    return NEW;
  end if;
  if NEW.source_type = 'shop_order_item'::public.preorder_demand_source_type then
    select o.profile_id
    into NEW.profile_id
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    where oi.id = NEW.source_id;
  elsif NEW.source_type = 'pbc_costing_item'::public.preorder_demand_source_type then
    select f.profile_id
    into NEW.profile_id
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    where pci.id = NEW.source_id;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_preorder_demand_stamp_profile on public.preorder_demand;
create trigger trg_preorder_demand_stamp_profile
before insert or update on public.preorder_demand
for each row execute function public.trg_fn_preorder_demand_stamp_profile();

update public.preorder_demand pd
set profile_id = o.profile_id
from public.shop_order_items oi
inner join public.shop_orders o on o.id = oi.order_id
where pd.source_type = 'shop_order_item'
  and pd.source_id = oi.id
  and pd.profile_id is null
  and o.profile_id is not null;

update public.preorder_demand pd
set profile_id = f.profile_id
from public.product_based_costing_items pci
inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
where pd.source_type = 'pbc_costing_item'
  and pd.source_id = pci.id
  and pd.profile_id is null
  and f.profile_id is not null;
