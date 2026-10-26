-- Phase 13A: Pay / Settle shipment costs (real wallet posts)

begin;

create or replace function public.pay_settle_shipment_costs(
  p_shipment_id bigint,
  p_cost_entry_ids bigint[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ship public.global_shipments%rowtype;
  v_entry public.global_shipment_cost_entries%rowtype;
  v_amount numeric;
  v_settled_count integer := 0;
  v_wallet_posted boolean := false;
  v_ledger jsonb;
  v_wallet_entity_type text;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if v_ship.status is distinct from 'received' then
    raise exception 'shipment must be received before settlement';
  end if;

  if not public.has_active_tenant_membership(v_ship.parent_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  for v_entry in
    select *
    from public.global_shipment_cost_entries
    where shipment_id = p_shipment_id
      and (p_cost_entry_ids is null or id = any(p_cost_entry_ids))
      and payment_source is not null
      and entity_type is not null
      and entity_id is not null
      and settled_at is null
  loop
    if v_entry.entity_type = 'shipment' then
      raise exception 'cost entry % cannot settle shipment entity', v_entry.id;
    end if;

    v_amount := round(coalesce(v_entry.amount, 0) * coalesce(v_entry.exchange_rate, 1), 4);
    if v_amount <= 0 then
      continue;
    end if;

    v_wallet_entity_type := case
      when v_entry.entity_type = 'cargo_company' then 'cargo_company'
      else v_entry.entity_type
    end;

    if v_entry.payment_source in ('cash', 'wallet') then
      v_ledger := public.record_ledger_transaction(
        p_tenant_id => v_ship.parent_tenant_id,
        p_entity_type => v_wallet_entity_type,
        p_entity_id => v_entry.entity_id,
        p_type => 'debit',
        p_amount => v_amount,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'shipment',
        p_source_id => p_shipment_id::text,
        p_metadata => jsonb_build_object(
          'cost_entry_id', v_entry.id,
          'payment_source', v_entry.payment_source,
          'purpose', 'shipment_cost_settle_payee'
        ),
        p_target_bucket => 'available'
      );

      v_ledger := public.record_ledger_transaction(
        p_tenant_id => v_ship.parent_tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => v_ship.parent_tenant_id,
        p_type => 'debit',
        p_amount => v_amount,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'shipment',
        p_source_id => p_shipment_id::text,
        p_metadata => jsonb_build_object(
          'cost_entry_id', v_entry.id,
          'payment_source', v_entry.payment_source,
          'purpose', 'shipment_cost_settle_tenant_cash'
        ),
        p_target_bucket => 'available'
      );
      v_wallet_posted := true;

    elsif v_entry.payment_source = 'credit' then
      v_ledger := public.record_ledger_transaction(
        p_tenant_id => v_ship.parent_tenant_id,
        p_entity_type => v_wallet_entity_type,
        p_entity_id => v_entry.entity_id,
        p_type => 'credit',
        p_amount => v_amount,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'shipment',
        p_source_id => p_shipment_id::text,
        p_metadata => jsonb_build_object(
          'cost_entry_id', v_entry.id,
          'payment_source', 'credit',
          'purpose', 'shipment_cost_credit_payable'
        ),
        p_target_bucket => 'pending'
      );
      v_wallet_posted := true;
    else
      raise exception 'unsupported payment_source % on entry %', v_entry.payment_source, v_entry.id;
    end if;

    update public.global_shipment_cost_entries
    set
      settled_at = now(),
      settlement_ledger_id = coalesce((v_ledger->>'id')::uuid, settlement_ledger_id),
      updated_at = now()
    where id = v_entry.id;

    v_settled_count := v_settled_count + 1;
  end loop;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'settled_entries_count', v_settled_count,
    'wallet_posted', v_wallet_posted and v_settled_count > 0
  );
end;
$$;

grant execute on function public.pay_settle_shipment_costs(bigint, bigint[]) to authenticated;

commit;
