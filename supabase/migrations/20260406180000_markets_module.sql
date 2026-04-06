-- =========================================================
-- Markets module: schema, RLS, grants, and system-row protections
-- Superadmins maintain this table.
-- =========================================================

create table public.markets (
  id bigserial primary key,
  name text not null,
  code text not null unique,
  is_active boolean not null default true,
  is_system boolean not null default false,
  region text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint markets_code_uppercase_check check (code = upper(code))
);

create index markets_code_idx on public.markets(code);
create index markets_region_idx on public.markets(region);

create trigger trg_markets_updated_at
before update on public.markets
for each row execute function public.set_updated_at();

create or replace function public.prevent_system_market_mutation()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    if old.is_system then
      raise exception 'System markets cannot be deleted.';
    end if;

    return old;
  end if;

  if tg_op = 'UPDATE' then
    if old.is_system and (
      row(new.name, new.code, new.is_active, new.is_system, new.region)
      is distinct from
      row(old.name, old.code, old.is_active, old.is_system, old.region)
    ) then
      raise exception 'System markets cannot be edited.';
    end if;

    return new;
  end if;

  return new;
end;
$$;

create trigger trg_markets_protect_system_rows
before update or delete on public.markets
for each row execute function public.prevent_system_market_mutation();

alter table public.markets enable row level security;

create policy "superadmin_can_manage_markets"
on public.markets
for all
to authenticated
using (
  public.is_superadmin()
)
with check (
  public.is_superadmin()
);

grant select, insert, update, delete
on table public.markets
to authenticated;

grant usage, select
on sequence public.markets_id_seq
to authenticated;
