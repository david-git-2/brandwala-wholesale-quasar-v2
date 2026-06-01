-- Create commerce_order_settings table
create table if not exists public.commerce_order_settings (
  tenant_id bigint primary key,
  default_cod_percent numeric(5, 2) not null default 0.00,
  default_delivery_charge numeric(12, 2) not null default 0.00,
  default_wrapping_charge numeric(12, 2) not null default 0.00,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint commerce_order_settings_tenant_id_fkey
    foreign key (tenant_id)
    references public.tenants (id)
    on delete cascade
);

-- Enable RLS
alter table public.commerce_order_settings enable row level security;

-- Policies
drop policy if exists commerce_order_settings_select on public.commerce_order_settings;
create policy commerce_order_settings_select on public.commerce_order_settings for select to authenticated using (true);

drop policy if exists commerce_order_settings_insert on public.commerce_order_settings;
create policy commerce_order_settings_insert on public.commerce_order_settings for insert to authenticated with check (true);

drop policy if exists commerce_order_settings_update on public.commerce_order_settings;
create policy commerce_order_settings_update on public.commerce_order_settings for update to authenticated using (true);

drop policy if exists commerce_order_settings_delete on public.commerce_order_settings;
create policy commerce_order_settings_delete on public.commerce_order_settings for delete to authenticated using (true);

-- Grant privileges
grant select, insert, update, delete on table public.commerce_order_settings to authenticated;

-- Function/Trigger for updated_at
drop trigger if exists trg_commerce_order_settings_updated_at on public.commerce_order_settings;
create trigger trg_commerce_order_settings_updated_at
before update on public.commerce_order_settings
for each row
execute function public.set_updated_at();
