-- Phase 2: cost entry CRUD RPCs (blocked after finalize / stock_ready)

begin;

create or replace function public.list_global_shipment_cost_entries(p_shipment_id bigint)
returns setof public.global_shipment_cost_entries
language plpgsql
security definer
set search_path = public
as $$
declare
  v_parent bigint;
begin
  select parent_tenant_id into v_parent
  from public.global_shipments
  where id = p_shipment_id;

  if v_parent is null then
    raise exception 'shipment not found';
  end if;

  if not (
    public.user_can_manage_parent_tenant(v_parent)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_parent
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  ) then
    raise exception 'not allowed';
  end if;

  return query
  select e.*
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
  order by e.cost_type, e.id;
end;
$$;

revoke all on function public.list_global_shipment_cost_entries(bigint) from public;
grant execute on function public.list_global_shipment_cost_entries(bigint) to authenticated;

-- ---------------------------------------------------------------------------

create or replace function public.upsert_global_shipment_cost_entry(
  p_shipment_id bigint,
  p_cost_type public.global_shipment_cost_type,
  p_amount numeric,
  p_exchange_rate numeric default 1.0,
  p_currency_id bigint default null,
  p_payment_source text default null,
  p_entity_type text default null,
  p_entity_id bigint default null,
  p_allocation text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_id bigint default null
)
returns public.global_shipment_cost_entries
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ship public.global_shipments%rowtype;
  v_row public.global_shipment_cost_entries%rowtype;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_ship.stock_ready = true or v_ship.status = 'Ready Stock' then
    raise exception 'shipment finalized; use revise_global_shipment_costs';
  end if;

  if p_amount is null or p_amount < 0 then
    raise exception 'amount must be >= 0';
  end if;

  if p_exchange_rate is null or p_exchange_rate <= 0 then
    raise exception 'exchange_rate must be > 0';
  end if;

  if p_id is not null then
    update public.global_shipment_cost_entries e
    set
      cost_type = p_cost_type,
      amount = p_amount,
      exchange_rate = p_exchange_rate,
      currency_id = p_currency_id,
      payment_source = p_payment_source,
      entity_type = p_entity_type,
      entity_id = p_entity_id,
      allocation = p_allocation,
      metadata = coalesce(p_metadata, '{}'::jsonb),
      updated_at = now()
    where e.id = p_id
      and e.shipment_id = p_shipment_id
    returning * into v_row;

    if not found then
      raise exception 'cost entry % not found on shipment %', p_id, p_shipment_id;
    end if;
  else
    insert into public.global_shipment_cost_entries (
      parent_tenant_id,
      shipment_id,
      cost_type,
      amount,
      currency_id,
      exchange_rate,
      payment_source,
      entity_type,
      entity_id,
      allocation,
      metadata
    ) values (
      v_ship.parent_tenant_id,
      p_shipment_id,
      p_cost_type,
      p_amount,
      p_currency_id,
      p_exchange_rate,
      p_payment_source,
      p_entity_type,
      p_entity_id,
      p_allocation,
      coalesce(p_metadata, '{}'::jsonb)
    )
    returning * into v_row;
  end if;

  return v_row;
end;
$$;

revoke all on function public.upsert_global_shipment_cost_entry(
  bigint, public.global_shipment_cost_type, numeric, numeric, bigint, text, text, bigint, text, jsonb, bigint
) from public;
grant execute on function public.upsert_global_shipment_cost_entry(
  bigint, public.global_shipment_cost_type, numeric, numeric, bigint, text, text, bigint, text, jsonb, bigint
) to authenticated;

-- ---------------------------------------------------------------------------

create or replace function public.delete_global_shipment_cost_entry(p_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_entry public.global_shipment_cost_entries%rowtype;
  v_ship public.global_shipments%rowtype;
begin
  select * into v_entry from public.global_shipment_cost_entries where id = p_id;
  if not found then
    raise exception 'cost entry not found';
  end if;

  select * into v_ship from public.global_shipments where id = v_entry.shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_ship.stock_ready = true or v_ship.status = 'Ready Stock' then
    raise exception 'shipment finalized; use revise_global_shipment_costs';
  end if;

  delete from public.global_shipment_cost_entries where id = p_id;
end;
$$;

revoke all on function public.delete_global_shipment_cost_entry(bigint) from public;
grant execute on function public.delete_global_shipment_cost_entry(bigint) to authenticated;

commit;
