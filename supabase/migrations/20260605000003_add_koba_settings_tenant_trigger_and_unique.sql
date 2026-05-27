begin;

-- 1. Clean up duplicate koba_retail_settings rows (if any exist) keeping the earliest one
delete from public.koba_retail_settings a using public.koba_retail_settings b
where a.id > b.id and a.tenant_id = b.tenant_id;

-- 2. Add unique constraint on tenant_id
alter table public.koba_retail_settings
add constraint koba_retail_settings_tenant_id_key unique (tenant_id);

-- 3. Trigger function to auto-create settings when a new tenant is created
create or replace function public.handle_new_tenant_retail_settings()
returns trigger as $$
begin
  insert into public.koba_retail_settings (tenant_id)
  values (new.id)
  on conflict (tenant_id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

-- 4. Create trigger on tenants table
drop trigger if exists on_tenant_created_retail_settings on public.tenants;
create trigger on_tenant_created_retail_settings
  after insert on public.tenants
  for each row
  execute function public.handle_new_tenant_retail_settings();

commit;
