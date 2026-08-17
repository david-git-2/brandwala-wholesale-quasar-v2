-- tenants use parent_id, not parent_tenant_id. Assign may target this company or a child.

create or replace function public.assign_shipment_to_child(
  p_parent_tenant_id bigint,
  p_child_tenant_id bigint,
  p_shipment_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ship public.global_shipments%rowtype;
  v_child_exists boolean;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
    and parent_tenant_id = p_parent_tenant_id
  for update;

  if not found then
    raise exception 'shipment not found or tenant mismatch';
  end if;

  if v_ship.status is distinct from 'received' then
    raise exception 'shipment must be received before assignment';
  end if;

  if not public.has_active_tenant_membership(p_parent_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_child_tenant_id is not null then
    select exists(
      select 1 from public.tenants t
      where t.id = p_child_tenant_id
        and (t.id = p_parent_tenant_id or t.parent_id = p_parent_tenant_id)
    ) into v_child_exists;

    if not v_child_exists then
      raise exception 'invalid child tenant for this parent';
    end if;
  end if;

  update public.global_shipments
  set assigned_child_tenant_id = p_child_tenant_id,
      updated_at = now()
  where id = p_shipment_id;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'assigned_child_tenant_id', p_child_tenant_id
  );
end;
$$;

grant execute on function public.assign_shipment_to_child(bigint, bigint, bigint) to authenticated;
