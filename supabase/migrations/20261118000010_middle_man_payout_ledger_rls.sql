-- Enable RLS on middle_man_payout_ledger: authenticated tenant members only.
-- Ledger writes stay in security definer RPCs (bypass RLS).

begin;

alter table public.middle_man_payout_ledger enable row level security;

revoke all on table public.middle_man_payout_ledger from anon;
revoke all on table public.middle_man_payout_ledger from public;

grant select on table public.middle_man_payout_ledger to authenticated;
grant all on table public.middle_man_payout_ledger to service_role;

drop policy if exists "Authenticated users can select tenant payout ledger"
  on public.middle_man_payout_ledger;
drop policy if exists middle_man_payout_ledger_select
  on public.middle_man_payout_ledger;

create policy middle_man_payout_ledger_select
  on public.middle_man_payout_ledger
  for select
  to authenticated
  using (
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = middle_man_payout_ledger.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  );

commit;
