alter table public.invoices
  add column if not exists billing_profile_id bigint null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'invoices_billing_profile_id_fkey'
      and conrelid = 'public.invoices'::regclass
  ) then
    alter table public.invoices
      add constraint invoices_billing_profile_id_fkey
      foreign key (billing_profile_id)
      references public.billing_profiles(id)
      on delete set null;
  end if;
end $$;

create index if not exists invoices_billing_profile_id_idx
  on public.invoices (billing_profile_id);
