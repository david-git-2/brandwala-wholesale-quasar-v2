begin;

-- =========================================================
-- Treasury / reporting domain RLS cutover
-- payments → global_payments (20260829000000 rename)
-- =========================================================
do $$
declare
  v_payments_table text := null;
  v_alloc_table text := null;
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'global_payments'
  ) then
    v_payments_table := 'global_payments';
    v_alloc_table := 'invoice_payments';
  elsif exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'payments'
  ) then
    v_payments_table := 'payments';
    v_alloc_table := 'payment_allocations';
  else
    return;
  end if;

  execute format('drop policy if exists payments_insert on public.%I', v_payments_table);
  execute format($policy$
    create policy payments_insert on public.%1$I
    for insert to authenticated
    with check (public.membership_has_module_action(tenant_id, 'payments', 'collect_payment'))
  $policy$, v_payments_table);

  execute format('drop policy if exists payments_update on public.%I', v_payments_table);
  execute format($policy$
    create policy payments_update on public.%1$I
    for update to authenticated
    using (public.membership_has_module_action(tenant_id, 'payments', 'allocate_payment'))
    with check (public.membership_has_module_action(tenant_id, 'payments', 'allocate_payment'))
  $policy$, v_payments_table);

  execute format('drop policy if exists payments_delete on public.%I', v_payments_table);
  execute format($policy$
    create policy payments_delete on public.%1$I
    for delete to authenticated
    using (public.membership_has_module_action(tenant_id, 'payments', 'void'))
  $policy$, v_payments_table);

  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = v_alloc_table
  ) then
    execute format('drop policy if exists payment_allocations_insert on public.%I', v_alloc_table);
    execute format($policy$
      create policy payment_allocations_insert on public.%1$I
      for insert to authenticated
      with check (
        exists (
          select 1 from public.%2$I p
          where p.id = payment_id
            and public.membership_has_module_action(p.tenant_id, 'payments', 'allocate_payment')
        )
      )
    $policy$, v_alloc_table, v_payments_table);

    execute format('drop policy if exists payment_allocations_update on public.%I', v_alloc_table);
    execute format($policy$
      create policy payment_allocations_update on public.%1$I
      for update to authenticated
      using (
        exists (
          select 1 from public.%2$I p
          where p.id = payment_id
            and public.membership_has_module_action(p.tenant_id, 'payments', 'allocate_payment')
        )
      )
      with check (
        exists (
          select 1 from public.%2$I p
          where p.id = payment_id
            and public.membership_has_module_action(p.tenant_id, 'payments', 'allocate_payment')
        )
      )
    $policy$, v_alloc_table, v_payments_table);

    execute format('drop policy if exists payment_allocations_delete on public.%I', v_alloc_table);
    execute format($policy$
      create policy payment_allocations_delete on public.%1$I
      for delete to authenticated
      using (
        exists (
          select 1 from public.%2$I p
          where p.id = payment_id
            and public.membership_has_module_action(p.tenant_id, 'payments', 'void')
        )
      )
    $policy$, v_alloc_table, v_payments_table);
  end if;
end $$;

commit;
