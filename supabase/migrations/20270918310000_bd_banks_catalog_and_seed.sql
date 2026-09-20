begin;

-- =========================================================
-- Bangladesh banks catalog (global reference)
-- Used by wallet cheque instrument lines (bd_bank_id).
-- =========================================================

insert into public.modules (key, name, description, is_active, parent_module_key)
values (
  'global_reference_bd_bank',
  'BD Banks',
  'Bangladesh scheduled bank catalog for cheque receipt lines.',
  true,
  'global_reference'
)
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active,
  parent_module_key = excluded.parent_module_key;

create table if not exists public.bd_banks (
  id bigserial primary key,
  code text not null unique,
  name text not null,
  swift_code text null,
  sort_order int not null default 0,
  is_active boolean not null default true,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint bd_banks_code_uppercase_check check (code = upper(code))
);

create index if not exists bd_banks_code_idx on public.bd_banks(code);
create index if not exists bd_banks_sort_order_idx on public.bd_banks(sort_order);

create trigger trg_bd_banks_updated_at
before update on public.bd_banks
for each row execute function public.set_updated_at();

create or replace function public.prevent_system_bd_bank_mutation()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    if old.is_system then
      raise exception 'System BD banks cannot be deleted.';
    end if;
    return old;
  end if;

  if tg_op = 'UPDATE' and old.is_system and (
    row(new.code, new.name, new.swift_code, new.sort_order, new.is_active, new.is_system)
    is distinct from
    row(old.code, old.name, old.swift_code, old.sort_order, old.is_active, old.is_system)
  ) then
    raise exception 'System BD banks cannot be edited.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_bd_banks_protect_system_rows on public.bd_banks;

create trigger trg_bd_banks_protect_system_rows
before update or delete on public.bd_banks
for each row execute function public.prevent_system_bd_bank_mutation();

alter table public.bd_banks enable row level security;

drop policy if exists superadmin_can_manage_bd_banks on public.bd_banks;

create policy superadmin_can_manage_bd_banks
on public.bd_banks
for all
to authenticated
using (public.is_superadmin())
with check (public.is_superadmin());

grant select, insert, update, delete on table public.bd_banks to authenticated;
grant usage, select on sequence public.bd_banks_id_seq to authenticated;

insert into public.bd_banks (code, name, swift_code, sort_order, is_active, is_system)
values
  -- State-owned & specialized
  ('SONALI', 'Sonali Bank PLC', 'BSONBDDH', 10, true, true),
  ('JANATA', 'Janata Bank PLC', 'JANBBDDH', 20, true, true),
  ('AGRANI', 'Agrani Bank PLC', 'AGBKBDDH', 30, true, true),
  ('RUPALI', 'Rupali Bank PLC', 'RUPBBDDH', 40, true, true),
  ('BASIC', 'BASIC Bank Limited', 'BKSIBDDH', 50, true, true),
  ('BDBL', 'Bangladesh Development Bank Limited', 'BDDBBDDH', 60, true, true),
  ('BKB', 'Bangladesh Krishi Bank', 'BKBABDDH', 70, true, true),
  ('RAKUB', 'Rajshahi Krishi Unnayan Bank', 'RKUBBDDH', 80, true, true),
  ('PKB', 'Probashi Kallyan Bank', 'PKBBDDH', 90, true, true),
  ('KARMOSANGSTHAN', 'Karmasangsthan Bank', null, 100, true, true),
  -- Major private & foreign banks
  ('CITY', 'City Bank PLC', 'CIBLBDDH', 110, true, true),
  ('BRAC', 'BRAC Bank PLC', 'BRAKBDDH', 120, true, true),
  ('EBL', 'Eastern Bank Limited', 'EBLBDDH', 130, true, true),
  ('DBBL', 'Dutch-Bangla Bank PLC', 'DBBLBDDH', 140, true, true),
  ('IBBL', 'Islami Bank Bangladesh PLC', 'IBBLBDDH', 150, true, true),
  ('MTB', 'Mutual Trust Bank PLC', 'MTBLBDDH', 160, true, true),
  ('NBL', 'National Bank Limited', 'NBLBBDDH', 170, true, true),
  ('PREMIER', 'Premier Bank Limited', 'PRBLBDDH', 180, true, true),
  ('SEBL', 'Southeast Bank Limited', 'SEBDBDDH', 190, true, true),
  ('DHAKA', 'Dhaka Bank Limited', 'DHBLBDDH', 200, true, true),
  ('PUBALI', 'Pubali Bank PLC', 'PUBABDDH', 210, true, true),
  ('UCB', 'United Commercial Bank PLC', 'UCBLBDDH', 220, true, true),
  ('STANDARD', 'Standard Bank Limited', 'SDBLBDDH', 230, true, true),
  ('ONE', 'One Bank Limited', 'ONEBBDDH', 240, true, true),
  ('MBL', 'Mercantile Bank Limited', 'MBLBBDDH', 250, true, true),
  ('EXIM', 'Export Import Bank of Bangladesh PLC', 'EXBKBDDH', 260, true, true),
  ('IFIC', 'IFIC Bank PLC', 'IFICBDDH', 270, true, true),
  ('JAMUNA', 'Jamuna Bank Limited', 'JAMUBDDH', 280, true, true),
  ('PRIME', 'Prime Bank Limited', 'PRIMBDDH', 290, true, true),
  ('TRUST', 'Trust Bank Limited', 'TTBLBDDH', 300, true, true),
  ('BANKASIA', 'Bank Asia Limited', 'BALBBDDH', 310, true, true),
  ('AB', 'AB Bank Limited', 'ABBLBDDH', 320, true, true),
  ('AAIB', 'Al-Arafah Islami Bank PLC', 'ARAFBDDH', 330, true, true),
  ('FSIBL', 'First Security Islami Bank PLC', 'FSEBBDDH', 340, true, true),
  ('SJIBL', 'Shahjalal Islami Bank PLC', 'SJBLBDDH', 350, true, true),
  ('SIBL', 'Social Islami Bank Limited', 'SOIVBDDH', 360, true, true),
  ('ICB', 'ICB Islamic Bank Limited', 'ICBBDDH', 370, true, true),
  ('UNION', 'Union Bank Limited', 'UNILBDDH', 380, true, true),
  ('NRB', 'NRB Bank Limited', 'NRBBBDDH', 390, true, true),
  ('NRBC', 'NRB Commercial Bank Limited', 'NRBCBDDH', 400, true, true),
  ('NRBG', 'NRB Global Bank Limited', 'NRBGBDDH', 410, true, true),
  ('MODHUMOTI', 'Modhumoti Bank Limited', 'MODHBDDH', 420, true, true),
  ('PADMA', 'Padma Bank Limited', 'PADMBDDH', 430, true, true),
  ('BCB', 'Bengal Commercial Bank Limited', 'BCBLBDDH', 440, true, true),
  ('MEGHNA', 'Meghna Bank Limited', 'MGBLBDDH', 450, true, true),
  ('MIDLAND', 'Midland Bank Limited', 'MIDLBDDH', 460, true, true),
  ('SBAC', 'South Bangla Agriculture and Commerce Bank Limited', 'SBACBDDH', 470, true, true),
  ('COMMUNITY', 'Community Bank Bangladesh Limited', 'COYMBDDH', 480, true, true),
  ('CITIZENS', 'Citizens Bank PLC', 'CIZTBDDH', 490, true, true),
  ('SHIMANTO', 'Shimanto Bank Limited', 'SHMTBDDH', 500, true, true),
  ('GLOBAL_ISLAMI', 'Global Islami Bank PLC', 'GLBLBDDH', 510, true, true),
  ('SB', 'Standard Chartered Bank', 'SCBLBDDX', 520, true, true),
  ('HSBC', 'HSBC Bank Bangladesh', 'HSBCBDDH', 530, true, true),
  ('CITI', 'Citibank N.A. Bangladesh', 'CITIBDDX', 540, true, true),
  ('WAB', 'Woori Bank Bangladesh', 'HVBKBDDH', 550, true, true),
  ('MUFG', 'MUFG Bank Ltd. Dhaka Branch', 'BOTKBDDX', 560, true, true),
  ('HBL', 'Habib Bank Limited', 'HABBBDDH', 570, true, true),
  ('SBI', 'State Bank of India', 'SBINBDDH', 580, true, true),
  ('UCO', 'UCO Bank', 'UCBABDDH', 590, true, true),
  ('BOC', 'Bank of Ceylon', 'BCEYBDDH', 600, true, true)
on conflict (code) do update
set
  name = excluded.name,
  swift_code = excluded.swift_code,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  is_system = excluded.is_system;

select setval(
  'public.bd_banks_id_seq',
  (select coalesce(max(id), 1) from public.bd_banks),
  true
);

create or replace function public.list_bd_banks()
returns table(
  id bigint,
  code text,
  name text,
  swift_code text,
  sort_order int
)
language sql
security definer
set search_path = public
stable
as $$
  select b.id, b.code, b.name, b.swift_code, b.sort_order
  from public.bd_banks b
  where b.is_active = true
  order by b.sort_order asc, b.name asc;
$$;

grant execute on function public.list_bd_banks() to authenticated;

commit;
