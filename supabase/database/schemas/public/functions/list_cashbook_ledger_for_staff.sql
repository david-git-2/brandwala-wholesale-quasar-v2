CREATE FUNCTION public.list_cashbook_ledger_for_staff (
  p_tenant_id           bigint,
  p_entity_type         text,
  p_entity_id           bigint,
  p_search              text    DEFAULT NULL::text,
  p_operating_tenant_id bigint  DEFAULT NULL::bigint,
  p_limit               integer DEFAULT 50,
  p_offset              integer DEFAULT 0
)
  RETURNS TABLE (
    id                  uuid,
    parent_tenant_id    bigint,
    operating_tenant_id bigint,
    entity_type         text,
    entity_id           bigint,
    type                text,
    amount              numeric,
    currency_code       text,
    exchange_rate       numeric,
    base_amount         numeric,
    balance_after       numeric,
    source_type         text,
    source_id           text,
    metadata            jsonb,
    created_at          timestamp with time zone,
    is_reversal         boolean,
    reversed_entry_id   uuid,
    cashbook_point_id   bigint,
    cashbook_point_name text
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_books_id bigint;
  v_entity_id bigint;
  v_search text;
BEGIN
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN v_entity_id := v_books_id; END IF;

  IF NOT public.cashbook_staff_can_view(p_tenant_id) THEN RETURN; END IF;

  v_search := nullif(trim(p_search), '');

  RETURN QUERY
  SELECT
    l.id,
    l.parent_tenant_id,
    l.operating_tenant_id,
    l.entity_type,
    l.entity_id,
    l.type,
    l.amount,
    l.currency_code,
    l.exchange_rate,
    l.base_amount,
    l.balance_after,
    l.source_type,
    l.source_id,
    l.metadata,
    l.created_at,
    (l.metadata ? 'reversal_of'),
    CASE WHEN l.metadata ? 'reversal_of' THEN (l.metadata->>'reversal_of')::uuid ELSE NULL END,
    l.cashbook_point_id,
    cp.name
  FROM public.cashbook_entries l
  LEFT JOIN public.cashbook_points cp ON cp.id = l.cashbook_point_id
  WHERE l.parent_tenant_id = v_books_id
    AND l.entity_type = p_entity_type
    AND l.entity_id = v_entity_id
    AND (p_operating_tenant_id IS NULL OR l.operating_tenant_id = p_operating_tenant_id)
    AND (
      v_search IS NULL
      OR coalesce(l.source_id, '') ILIKE '%' || v_search || '%'
      OR coalesce(l.metadata->>'note', '') ILIKE '%' || v_search || '%'
      OR coalesce(l.metadata->>'trx_id', '') ILIKE '%' || v_search || '%'
      OR coalesce(l.metadata->>'section', '') ILIKE '%' || v_search || '%'
      OR coalesce(l.source_type, '') ILIKE '%' || v_search || '%'
      OR coalesce(cp.name, '') ILIKE '%' || v_search || '%'
    )
  ORDER BY l.created_at DESC, l.id DESC
  LIMIT greatest(least(coalesce(p_limit, 50), 200), 1)
  OFFSET greatest(coalesce(p_offset, 0), 0);
END;
$function$;

GRANT ALL ON FUNCTION public.list_cashbook_ledger_for_staff(bigint, text, bigint, text, bigint, integer, integer) TO anon;

GRANT ALL ON FUNCTION public.list_cashbook_ledger_for_staff(bigint, text, bigint, text, bigint, integer, integer) TO authenticated;

GRANT ALL ON FUNCTION public.list_cashbook_ledger_for_staff(bigint, text, bigint, text, bigint, integer, integer) TO service_role;