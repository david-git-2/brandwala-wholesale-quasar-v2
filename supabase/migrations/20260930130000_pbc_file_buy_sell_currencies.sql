-- PBC file buy/sell currencies (default GBP buy, BDT sell).

alter table public.product_based_costing_files
  add column if not exists buy_currency_id bigint,
  add column if not exists buy_currency_code text,
  add column if not exists sell_currency_id bigint,
  add column if not exists sell_currency_code text;

do $$
declare
  v_gbp_id bigint;
  v_bdt_id bigint;
begin
  select id into v_gbp_id from public.global_currencies where code = 'GBP' limit 1;
  select id into v_bdt_id from public.global_currencies where code = 'BDT' limit 1;

  if v_gbp_id is null then
    raise exception 'global_currencies must include GBP before PBC currency migration';
  end if;
  if v_bdt_id is null then
    raise exception 'global_currencies must include BDT before PBC currency migration';
  end if;

  update public.product_based_costing_files f
     set buy_currency_id = v_gbp_id,
         buy_currency_code = 'GBP',
         sell_currency_id = v_bdt_id,
         sell_currency_code = 'BDT'
   where f.buy_currency_id is null
      or f.sell_currency_id is null
      or f.buy_currency_code is null
      or f.sell_currency_code is null;
end $$;

alter table public.product_based_costing_files
  alter column buy_currency_id set not null,
  alter column buy_currency_code set not null,
  alter column sell_currency_id set not null,
  alter column sell_currency_code set not null;

do $$ begin
  alter table public.product_based_costing_files
    add constraint product_based_costing_files_buy_currency_id_fkey
    foreign key (buy_currency_id) references public.global_currencies(id);
exception
  when duplicate_object then null;
end $$;

do $$ begin
  alter table public.product_based_costing_files
    add constraint product_based_costing_files_sell_currency_id_fkey
    foreign key (sell_currency_id) references public.global_currencies(id);
exception
  when duplicate_object then null;
end $$;

create or replace function public.trg_fn_pbc_files_stamp_currency_codes()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_gbp_id bigint;
  v_bdt_id bigint;
begin
  select id into v_gbp_id from public.global_currencies where code = 'GBP' limit 1;
  select id into v_bdt_id from public.global_currencies where code = 'BDT' limit 1;

  if v_gbp_id is null then
    raise exception 'global_currencies must include GBP for product_based_costing_files defaults';
  end if;
  if v_bdt_id is null then
    raise exception 'global_currencies must include BDT for product_based_costing_files defaults';
  end if;

  if new.buy_currency_id is null then
    new.buy_currency_id := v_gbp_id;
  end if;
  if new.sell_currency_id is null then
    new.sell_currency_id := v_bdt_id;
  end if;

  select gc.code into new.buy_currency_code
    from public.global_currencies gc
   where gc.id = new.buy_currency_id;

  if new.buy_currency_code is null then
    raise exception 'unknown buy_currency_id %', new.buy_currency_id;
  end if;

  select gc.code into new.sell_currency_code
    from public.global_currencies gc
   where gc.id = new.sell_currency_id;

  if new.sell_currency_code is null then
    raise exception 'unknown sell_currency_id %', new.sell_currency_id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_pbc_files_stamp_currency_codes on public.product_based_costing_files;

create trigger trg_pbc_files_stamp_currency_codes
  before insert or update of buy_currency_id, sell_currency_id
  on public.product_based_costing_files
  for each row
  execute function public.trg_fn_pbc_files_stamp_currency_codes();
