-- Shipment Public Tracking Token
-- Adds a shareable public token per shipment and a no-auth read RPC.

-- ---------------------------------------------------------------------------
-- 1. Add public_tracking_token column to global_shipments
-- ---------------------------------------------------------------------------

alter table public.global_shipments
  add column if not exists public_tracking_token text default null;

create unique index if not exists global_shipments_public_tracking_token_key
  on public.global_shipments (public_tracking_token)
  where public_tracking_token is not null;

comment on column public.global_shipments.public_tracking_token is
  'Random token for unauthenticated public tracking page. NULL = no link generated yet.';

-- ---------------------------------------------------------------------------
-- 2. Generate or regenerate a public tracking token (authenticated)
-- ---------------------------------------------------------------------------

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

  -- Generate a URL-safe token (32 hex chars = 128-bit)
  v_token := encode(gen_random_bytes(16), 'hex');

  update public.global_shipments
  set public_tracking_token = v_token, updated_at = now()
  where id = p_shipment_id;

  return v_token;
end;
$$;

grant execute on function public.generate_shipment_tracking_token(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Revoke public tracking token (authenticated)
-- ---------------------------------------------------------------------------

create or replace function public.revoke_shipment_tracking_token(
  p_shipment_id bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ship public.global_shipments%rowtype;
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

  update public.global_shipments
  set public_tracking_token = null, updated_at = now()
  where id = p_shipment_id;
end;
$$;

grant execute on function public.revoke_shipment_tracking_token(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Public read RPC — no auth required, safe payload only
--    Returns: shipment label, lifecycle status, current progress tag,
--             full ordered active progress tags for this tenant.
--    Deliberately excludes: costs, vendor, cargo, financials.
-- ---------------------------------------------------------------------------

create or replace function public.get_shipment_public_status(
  p_token text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ship public.global_shipments%rowtype;
  v_progress_tag jsonb := null;
  v_progress_list jsonb := '[]'::jsonb;
  v_tag public.tags%rowtype;
begin
  if p_token is null or trim(p_token) = '' then
    return null;
  end if;

  select * into v_ship
  from public.global_shipments
  where public_tracking_token = p_token
    and deleted_at is null
  limit 1;

  if not found then
    return null;
  end if;

  -- Current progress tag
  if v_ship.progress_tag_id is not null then
    select * into v_tag
    from public.tags
    where id = v_ship.progress_tag_id
      and is_active = true
    limit 1;

    if found then
      v_progress_tag := jsonb_build_object(
        'id',         v_tag.id,
        'name',       v_tag.name,
        'color',      v_tag.color,
        'sort_order', v_tag.sort_order
      );
    end if;
  end if;

  -- Ordered active progress tags for this tenant
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id',         t.id,
      'name',       t.name,
      'color',      t.color,
      'sort_order', t.sort_order
    )
    order by t.sort_order nulls last, t.name
  ), '[]'::jsonb)
  into v_progress_list
  from public.tags t
  where t.tenant_id = v_ship.parent_tenant_id
    and t.group_name = 'shipment_progress'
    and t.is_active = true;

  return jsonb_build_object(
    'id',              v_ship.id,
    'name',            v_ship.name,
    'status',          v_ship.status,
    'progress_tag',    v_progress_tag,
    'progress_tags',   v_progress_list,
    'updated_at',      v_ship.updated_at
  );
end;
$$;

-- Intentionally grant to anon + authenticated for public access
grant execute on function public.get_shipment_public_status(text) to anon, authenticated;
