begin;

create table if not exists public.koba_retail_settings (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  
  cod_charge_pct numeric(5,2) default 1.00,
  gateway_charge_pct numeric(5,2) default 1.00,
  packing_charge_flat numeric(12,2) default 37.00,
  invoice_charge_flat numeric(12,2) default 1.00,
  
  extra_profit_user_pct numeric(5,2) default 90.00,
  extra_profit_company_pct numeric(5,2) default 10.00,
  
  delivery_rates jsonb default '{"default": 110, "Dhaka": 100, "Dhaka Sub-Urban": 100}'::jsonb,

  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- RLS
alter table public.koba_retail_settings enable row level security;

create policy "Users can read retail settings for their tenant"
  on public.koba_retail_settings
  for select
  to authenticated
  using (
    tenant_id = (select tenant_id from auth.users where id = auth.uid() limit 1)
  );

-- Trigger for updated_at
create or replace function public.handle_koba_retail_settings_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_koba_retail_settings_updated_at on public.koba_retail_settings;
create trigger set_koba_retail_settings_updated_at
  before update on public.koba_retail_settings
  for each row
  execute function public.handle_koba_retail_settings_updated_at();

-- Insert default settings for existing tenants
insert into public.koba_retail_settings (tenant_id)
select id from public.tenants
on conflict do nothing;

commit;
