-- generate_shipment_tracking_token used gen_random_bytes (pgcrypto / extensions),
-- but SET search_path = public hides that schema.

begin;

create or replace function public.generate_shipment_tracking_token(
  p_shipment_id bigint
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ship public.global_shipments%rowtype;
  v_token text;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.has_active_tenant_membership(v_ship.parent_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  v_token := replace(gen_random_uuid()::text, '-', '');

  update public.global_shipments
  set public_tracking_token = v_token, updated_at = now()
  where id = p_shipment_id;

  return v_token;
end;
$$;

grant execute on function public.generate_shipment_tracking_token(bigint) to authenticated;

commit;
