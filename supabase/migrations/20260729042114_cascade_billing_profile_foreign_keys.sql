-- Migration: Update Foreign Keys on billing_profiles to ON DELETE CASCADE / SET NULL
-- Note: at this timestamp the table is still public.payments (renamed later in
-- 20260829000000_reporting_treasury_rename_payments.sql).

-- 1. payments (later global_payments): ON DELETE CASCADE
do $$
begin
  if to_regclass('public.payments') is not null then
    execute 'alter table public.payments drop constraint if exists payments_billing_profile_id_fkey';
    begin
      execute $sql$
        alter table public.payments
          add constraint payments_billing_profile_id_fkey
          foreign key (billing_profile_id)
          references public.billing_profiles(id)
          on delete cascade
      $sql$;
    exception when duplicate_object then null;
    end;
  elsif to_regclass('public.global_payments') is not null then
    execute 'alter table public.global_payments drop constraint if exists payments_billing_profile_id_fkey';
    begin
      execute $sql$
        alter table public.global_payments
          add constraint payments_billing_profile_id_fkey
          foreign key (billing_profile_id)
          references public.billing_profiles(id)
          on delete cascade
      $sql$;
    exception when duplicate_object then null;
    end;
  else
    raise notice 'payments/global_payments missing — skip billing_profile FK cascade';
  end if;
end $$;

-- 2. global_invoices: ON DELETE SET NULL
do $$
begin
  if to_regclass('public.global_invoices') is null then
    raise notice 'global_invoices missing — skip billing_profile FK update';
    return;
  end if;

  execute 'alter table public.global_invoices drop constraint if exists global_invoices_billing_profile_id_fkey';
  begin
    execute $sql$
      alter table public.global_invoices
        add constraint global_invoices_billing_profile_id_fkey
        foreign key (billing_profile_id)
        references public.billing_profiles(id)
        on delete set null
    $sql$;
  exception when duplicate_object then null;
  end;
end $$;

-- 3. shop_orders: ON DELETE SET NULL
do $$
begin
  if to_regclass('public.shop_orders') is null then
    raise notice 'shop_orders missing — skip billing_profile FK update';
    return;
  end if;

  execute 'alter table public.shop_orders drop constraint if exists shop_orders_billing_profile_id_fkey';
  begin
    execute $sql$
      alter table public.shop_orders
        add constraint shop_orders_billing_profile_id_fkey
        foreign key (billing_profile_id)
        references public.billing_profiles(id)
        on delete set null
    $sql$;
  exception when duplicate_object then null;
  end;
end $$;
