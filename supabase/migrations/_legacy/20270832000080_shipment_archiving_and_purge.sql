-- Migration: Add shipment archiving and conditional deletion governance
-- 1. Add is_archived and archived_at columns to global_shipments
ALTER TABLE public.global_shipments
  ADD COLUMN IF NOT EXISTS is_archived boolean DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS archived_at timestamp with time zone;

COMMENT ON COLUMN public.global_shipments.is_archived IS 'Archival flag to move shipment out of active operational table view.';
COMMENT ON COLUMN public.global_shipments.archived_at IS 'Timestamp when the shipment was archived.';

-- 2. Index for filtering active vs archived shipments efficiently
CREATE INDEX IF NOT EXISTS global_shipments_parent_tenant_is_archived_idx
  ON public.global_shipments (parent_tenant_id, is_archived);

-- 3. Update list_global_shipments_paginated to filter by is_archived
CREATE OR REPLACE FUNCTION public.list_global_shipments_paginated(
  p_tenant_id bigint,
  p_page integer DEFAULT 1,
  p_page_size integer DEFAULT 20,
  p_search text DEFAULT NULL::text,
  p_status text DEFAULT NULL::text,
  p_is_archived boolean DEFAULT false
) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
declare
  v_total_count bigint;
  v_archived_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  -- Total count matching query filters
  select count(*)
  into v_total_count
  from public.global_shipments s
  where s.parent_tenant_id = p_tenant_id
    and (p_is_archived is null or s.is_archived = p_is_archived)
    and (p_status is null or p_status = '' or p_status = '__all__' or s.status = p_status)
    and (
      p_search is null or p_search = '' or (
        s.name ilike '%' || p_search || '%'
        or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
      )
    );

  -- Count of all archived shipments for tenant (for toolbar badge)
  select count(*)
  into v_archived_count
  from public.global_shipments s
  where s.parent_tenant_id = p_tenant_id
    and s.is_archived = true;

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      s.id as sort_id,
      (
        to_jsonb(s)
        || jsonb_build_object(
          'vendor_name', v.name,
          'vendor_code', v.code,
          'progress_tag',
          case
            when t.id is null then null
            else jsonb_build_object(
              'id', t.id,
              'name', t.name,
              'slug', t.slug,
              'group_name', t.group_name,
              'sort_order', t.sort_order,
              'color', t.color
            )
          end
        )
      ) as row_json
    from public.global_shipments s
    left join public.vendors v
      on v.id = s.vendor_id
    left join public.tags t
      on t.id = s.progress_tag_id
     and t.group_name = 'shipment_progress'
    where s.parent_tenant_id = p_tenant_id
      and (p_is_archived is null or s.is_archived = p_is_archived)
      and (p_status is null or p_status = '' or p_status = '__all__' or s.status = p_status)
      and (
        p_search is null or p_search = '' or (
          s.name ilike '%' || p_search || '%'
          or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
        )
      )
    order by s.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) q;

  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::float / p_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', p_page_size,
      'total_pages', v_total_pages,
      'archived_total', v_archived_count
    )
  );
end;
$_$;

ALTER FUNCTION public.list_global_shipments_paginated(bigint, integer, integer, text, text, boolean) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.list_global_shipments_paginated(bigint, integer, integer, text, text, boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.list_global_shipments_paginated(bigint, integer, integer, text, text, boolean) TO authenticated;

-- 4. archive_shipment RPC
CREATE OR REPLACE FUNCTION public.archive_shipment(p_id bigint) RETURNS public.global_shipments
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  update public.global_shipments
  set is_archived = true,
      archived_at = now(),
      updated_at = now()
  where id = p_id
  returning * into v_ship;

  return v_ship;
end;
$$;

ALTER FUNCTION public.archive_shipment(bigint) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.archive_shipment(bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.archive_shipment(bigint) TO authenticated;

-- 5. unarchive_shipment RPC
CREATE OR REPLACE FUNCTION public.unarchive_shipment(p_id bigint) RETURNS public.global_shipments
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  update public.global_shipments
  set is_archived = false,
      archived_at = null,
      updated_at = now()
  where id = p_id
  returning * into v_ship;

  return v_ship;
end;
$$;

ALTER FUNCTION public.unarchive_shipment(bigint) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.unarchive_shipment(bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.unarchive_shipment(bigint) TO authenticated;

-- 6. purge_archived_shipment RPC (Permanent hard delete for archived draft/cancelled only)
CREATE OR REPLACE FUNCTION public.purge_archived_shipment(p_id bigint) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_ship.is_archived is not true then
    raise exception 'shipment must be archived before it can be permanently deleted';
  end if;

  -- Only draft and cancelled shipments can be permanently deleted
  if v_ship.status not in ('draft', 'cancelled') then
    raise exception 'shipment in status % cannot be deleted; only archived draft or cancelled shipments may be purged', v_ship.status;
  end if;

  -- Verify no physical stock was ever created for this shipment
  if exists (
    select 1
    from public.global_stocks gs
    join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    where gsi.shipment_id = p_id
  ) or v_ship.stock_ready = true then
    raise exception 'cannot delete shipment: physical inventory records exist for this shipment';
  end if;

  -- Cascade delete child operational rows belonging directly to this global shipment
  delete from public.global_shipment_items where shipment_id = p_id;
  delete from public.global_shipment_sections where shipment_id = p_id;
  delete from public.global_shipment_boxes where shipment_id = p_id;
  delete from public.global_shipment_cost_entries where shipment_id = p_id;
  delete from public.shipment_investments where global_shipment_id = p_id;

  -- Delete the global shipment record
  delete from public.global_shipments where id = p_id;
end;
$$;

ALTER FUNCTION public.purge_archived_shipment(bigint) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.purge_archived_shipment(bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.purge_archived_shipment(bigint) TO authenticated;
