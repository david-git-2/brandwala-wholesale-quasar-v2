CREATE FUNCTION public.upsert_global_shipment_cost_entry (
  p_shipment_id      bigint,
  p_cost_bucket      public.global_shipment_cost_bucket,
  p_cost_component   public.global_shipment_cost_component,
  p_amount           numeric,
  p_currency_id      bigint                                DEFAULT NULL::bigint,
  p_metadata         jsonb                                 DEFAULT '{}'::jsonb,
  p_section_id       bigint                                DEFAULT NULL::bigint,
  p_id               bigint                                DEFAULT NULL::bigint,
  p_description      text                                  DEFAULT NULL::text,
  p_is_capitalizable boolean                               DEFAULT true
)
  RETURNS public.global_shipment_cost_entries
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are locked';
  end if;

  if p_amount is null or p_amount < 0 then
    raise exception 'amount must be >= 0';
  end if;

  if p_id is not null then
    update public.global_shipment_cost_entries e
    set
      cost_bucket = p_cost_bucket,
      cost_component = p_cost_component,
      is_capitalizable = coalesce(p_is_capitalizable, e.is_capitalizable),
      description = coalesce(p_description, e.description),
      amount = p_amount,
      currency_id = p_currency_id,
      metadata = coalesce(p_metadata, '{}'::jsonb),
      section_id = p_section_id,
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
      cost_bucket,
      cost_component,
      is_capitalizable,
      description,
      amount,
      currency_id,
      metadata,
      section_id
    ) values (
      v_ship.parent_tenant_id,
      p_shipment_id,
      p_cost_bucket,
      p_cost_component,
      coalesce(p_is_capitalizable, true),
      p_description,
      p_amount,
      p_currency_id,
      coalesce(p_metadata, '{}'::jsonb),
      p_section_id
    )
    returning * into v_row;
  end if;

  if coalesce(v_row.is_capitalizable, true)
     and exists (select 1 from public.global_shipment_items where shipment_id = p_shipment_id) then
    perform public.stamp_global_shipment_landed_costs(p_shipment_id);
  end if;

  return v_row;
end;
$function$;

GRANT ALL ON FUNCTION
  public.upsert_global_shipment_cost_entry(bigint, public.global_shipment_cost_bucket, public.global_shipment_cost_component, numeric, bigint, jsonb, bigint, bigint, text, boolean)
  TO anon;

GRANT ALL ON FUNCTION
  public.upsert_global_shipment_cost_entry(bigint, public.global_shipment_cost_bucket, public.global_shipment_cost_component, numeric, bigint, jsonb, bigint, bigint, text, boolean)
  TO authenticated;

GRANT ALL ON FUNCTION
  public.upsert_global_shipment_cost_entry(bigint, public.global_shipment_cost_bucket, public.global_shipment_cost_component, numeric, bigint, jsonb, bigint, bigint, text, boolean)
  TO service_role;