-- Migration: Add current_tenant_id helper and triggers
begin;

-- Create helper to get current selected tenant ID from request headers
create or replace function public.current_tenant_id()
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select nullif(current_setting('request.headers', true)::json->>'x-selected-tenant-id', '')::bigint
$$;

grant execute on function public.current_tenant_id() to authenticated;

-- Create trigger function to auto-assign tenant_id on insert if omitted
create or replace function public.set_tenant_id_on_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.tenant_id is null then
    new.tenant_id := public.current_tenant_id();
  end if;
  return new;
end;
$$;

grant execute on function public.set_tenant_id_on_insert() to authenticated;

-- Attach the trigger to products
drop trigger if exists trg_products_set_tenant_id on public.products;
create trigger trg_products_set_tenant_id
before insert on public.products
for each row
execute function public.set_tenant_id_on_insert();

commit;
