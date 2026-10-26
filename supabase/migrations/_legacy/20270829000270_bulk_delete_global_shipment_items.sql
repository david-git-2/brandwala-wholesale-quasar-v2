-- RPC: bulk_delete_global_shipment_items
CREATE OR REPLACE FUNCTION "public"."bulk_delete_global_shipment_items"(
  "p_shipment_id" bigint,
  "p_item_ids" bigint[]
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_parent bigint;
  v_deleted_count bigint;
  v_ref_count bigint;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  if p_item_ids is null or array_length(p_item_ids, 1) is null or array_length(p_item_ids, 1) = 0 then
    return 0;
  end if;

  -- 1. Check parent tenant & permissions
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

  -- 2. Verify none of the items are referenced in warehouse stocks
  select count(*) into v_ref_count
  from public.global_stocks
  where shipment_item_id = any(p_item_ids);

  if v_ref_count > 0 then
    raise exception 'One or more selected items cannot be deleted because they are referenced in Warehouse Stock.';
  end if;

  -- 3. Delete items in bulk atomically
  with deleted as (
    delete from public.global_shipment_items
    where shipment_id = p_shipment_id
      and id = any(p_item_ids)
    returning id
  )
  select count(*) into v_deleted_count from deleted;

  return v_deleted_count;
end;
$$;

ALTER FUNCTION "public"."bulk_delete_global_shipment_items"("p_shipment_id" bigint, "p_item_ids" bigint[]) OWNER TO "postgres";

REVOKE ALL ON FUNCTION "public"."bulk_delete_global_shipment_items"("p_shipment_id" bigint, "p_item_ids" bigint[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."bulk_delete_global_shipment_items"("p_shipment_id" bigint, "p_item_ids" bigint[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."bulk_delete_global_shipment_items"("p_shipment_id" bigint, "p_item_ids" bigint[]) TO "service_role";
