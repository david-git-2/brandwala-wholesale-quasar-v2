-- Concession-only collect posts a zero-amount receipt header linked to write-offs.

begin;

alter table public.global_payments drop constraint if exists payments_amount_check;

alter table public.global_payments add constraint payments_amount_check
  check (amount >= 0::numeric);

commit;
