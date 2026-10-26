begin;

-- =========================================================
-- Rename thrift_currencies → global_currencies
-- =========================================================

alter table public.thrift_currencies rename to global_currencies;

alter sequence if exists public.thrift_currencies_id_seq rename to global_currencies_id_seq;

alter trigger trg_thrift_currencies_updated_at on public.global_currencies
  rename to trg_global_currencies_updated_at;

drop policy select_thrift_currencies on public.global_currencies;

create policy select_global_currencies on public.global_currencies
  for select to authenticated
  using (is_active = true);

grant select on table public.global_currencies to authenticated;
grant usage, select on sequence public.global_currencies_id_seq to authenticated;

commit;
