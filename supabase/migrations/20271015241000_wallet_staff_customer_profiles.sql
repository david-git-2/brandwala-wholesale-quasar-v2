-- BP3: wallet staff customer list/detail must use profiles (billing_profiles dropped in 20271012240000).
CREATE OR REPLACE FUNCTION "public"."get_wallet_detail_for_staff"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_currency_code" "text" DEFAULT 'BDT'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_operating_id bigint;
  v_name text;
  v_code text;
  v_caption text;
  v_source_uuid uuid;
  v_entity_id bigint;
  v_account jsonb;
BEGIN
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_operating_id := p_tenant_id;
  v_entity_id := p_entity_id;

  IF NOT public.wallet_staff_can_view(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  IF p_entity_type = 'tenant' THEN
    v_entity_id := v_books_id;
    SELECT t.name INTO v_name FROM public.tenants t WHERE t.id = v_books_id;
    IF v_name IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'entity not found');
    END IF;
    v_caption := 'Company cash pool';

  ELSIF p_entity_type = 'customer' THEN
    SELECT
      CASE WHEN cg.name IS NOT NULL THEN cg.name || ' · ' || pr.name ELSE pr.name END,
      nullif(trim(concat_ws(' • ', pr.phone, pr.email)), '')
    INTO v_name, v_caption
    FROM public.profiles pr
    LEFT JOIN public.customer_groups cg ON cg.id = pr.customer_group_id
    WHERE pr.id = p_entity_id
      AND (pr.operating_tenant_id = v_books_id OR pr.operating_tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id));
    IF v_name IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'entity not found');
    END IF;

  ELSIF p_entity_type = 'vendor' THEN
    SELECT v.name, v.code, nullif(trim(concat_ws(' • ', v.phone, v.email)), '')
    INTO v_name, v_code, v_caption
    FROM public.vendors v WHERE v.id = p_entity_id AND v.parent_tenant_id = v_books_id;
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSIF p_entity_type = 'cargo_company' THEN
    SELECT c.name, c.code, nullif(trim(concat_ws(' • ', c.phone, c.email)), '')
    INTO v_name, v_code, v_caption
    FROM public.cargo_companies c WHERE c.id = p_entity_id AND c.parent_tenant_id = v_books_id;
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSIF p_entity_type = 'courier' THEN
    SELECT cs.name, upper(cs.code), coalesce(nullif(trim(cs.notes), ''), 'Courier service'), cs.id
    INTO v_name, v_code, v_caption, v_source_uuid
    FROM public.courier_services cs
    WHERE cs.wallet_entity_id = p_entity_id AND cs.is_active = true
      AND (cs.tenant_id IS NULL OR cs.tenant_id = v_books_id
           OR cs.tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id));
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSIF p_entity_type = 'investor' THEN
    SELECT i.name, nullif(trim(concat_ws(' • ', i.phone, i.email)), '')
    INTO v_name, v_caption
    FROM public.investors i WHERE i.id = p_entity_id AND i.tenant_id = v_books_id;
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'invalid entity_type');
  END IF;

  v_account := public.get_wallet_account_balances(v_books_id, p_entity_type, v_entity_id, p_currency_code);

  RETURN jsonb_build_object(
    'success', true,
    'books_tenant_id', v_books_id,
    'operating_tenant_id', v_operating_id,
    'entity', jsonb_build_object(
      'entity_type', p_entity_type,
      'entity_id', v_entity_id,
      'name', v_name,
      'code', v_code,
      'caption', v_caption,
      'source_uuid', v_source_uuid
    ),
    'account', jsonb_build_object(
      'currency_code', coalesce(v_account->>'currency_code', p_currency_code),
      'available_balance', coalesce((v_account->>'available_balance')::numeric, 0),
      'pending_balance', coalesce((v_account->>'pending_balance')::numeric, 0),
      'locked_balance', coalesce((v_account->>'locked_balance')::numeric, 0),
      'total_balance', coalesce((v_account->>'total_balance')::numeric, 0)
    ),
    'permissions', jsonb_build_object(
      'can_record_manual', public.wallet_staff_can_edit(p_tenant_id),
      'can_reverse', public.wallet_staff_can_edit(p_tenant_id)
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION "public"."list_wallet_entities_for_staff"("p_tenant_id" bigint, "p_entity_type" "text", "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 100, "p_offset" integer DEFAULT 0, "p_currency_code" "text" DEFAULT 'BDT'::"text") RETURNS TABLE("entity_id" bigint, "entity_type" "text", "name" "text", "code" "text", "caption" "text", "available_balance" numeric, "pending_balance" numeric, "locked_balance" numeric, "total_balance" numeric, "source_uuid" "uuid", "operating_tenant_id" bigint, "has_wallet_activity" boolean)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_search text;
  v_limit integer;
  v_offset integer;
BEGIN
  IF p_entity_type NOT IN ('customer', 'vendor', 'courier', 'cargo_company', 'investor') THEN
    RAISE EXCEPTION 'Invalid entity_type %. Allowed: customer, vendor, courier, cargo_company, investor', p_entity_type;
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  IF NOT public.wallet_staff_can_view(p_tenant_id) THEN
    RETURN;
  END IF;

  v_search := nullif(trim(p_search), '');
  v_limit := greatest(least(coalesce(p_limit, 100), 500), 1);
  v_offset := greatest(coalesce(p_offset, 0), 0);

  IF p_entity_type = 'customer' THEN
    RETURN QUERY
    SELECT
      pr.id,
      'customer'::text,
      CASE WHEN cg.name IS NOT NULL THEN cg.name || ' · ' || pr.name ELSE pr.name END,
      NULL::text,
      nullif(trim(concat_ws(' • ', pr.phone, pr.email)), ''),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      NULL::uuid,
      pr.operating_tenant_id,
      wa.id IS NOT NULL
    FROM public.profiles pr
    LEFT JOIN public.customer_groups cg ON cg.id = pr.customer_group_id
    LEFT JOIN public.cashbook_accounts wa
      ON wa.parent_tenant_id = v_books_id
     AND wa.entity_type = 'customer'
     AND wa.entity_id = pr.id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE pr.profile_type = 'customer'::public.profile_party_type
      AND (pr.operating_tenant_id = v_books_id
       OR pr.operating_tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id))
      AND (
        v_search IS NULL
        OR pr.name ILIKE '%' || v_search || '%'
        OR coalesce(cg.name, '') ILIKE '%' || v_search || '%'
        OR coalesce(pr.phone, '') ILIKE '%' || v_search || '%'
        OR coalesce(pr.email, '') ILIKE '%' || v_search || '%'
      )
    ORDER BY 3 ASC, pr.id ASC
    LIMIT v_limit OFFSET v_offset;

  ELSIF p_entity_type = 'vendor' THEN
    RETURN QUERY
    SELECT
      v.id, 'vendor'::text, v.name, v.code,
      nullif(trim(concat_ws(' • ', v.phone, v.email)), ''),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      NULL::uuid, v.parent_tenant_id, wa.id IS NOT NULL
    FROM public.vendors v
    LEFT JOIN public.cashbook_accounts wa
      ON wa.parent_tenant_id = v_books_id AND wa.entity_type = 'vendor' AND wa.entity_id = v.id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE v.parent_tenant_id = v_books_id
      AND (v_search IS NULL OR v.name ILIKE '%' || v_search || '%' OR coalesce(v.code, '') ILIKE '%' || v_search || '%')
    ORDER BY v.name ASC, v.id ASC
    LIMIT v_limit OFFSET v_offset;

  ELSIF p_entity_type = 'cargo_company' THEN
    RETURN QUERY
    SELECT
      c.id, 'cargo_company'::text, c.name, c.code,
      nullif(trim(concat_ws(' • ', c.phone, c.email)), ''),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      NULL::uuid, c.parent_tenant_id, wa.id IS NOT NULL
    FROM public.cargo_companies c
    LEFT JOIN public.cashbook_accounts wa
      ON wa.parent_tenant_id = v_books_id AND wa.entity_type = 'cargo_company' AND wa.entity_id = c.id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE c.parent_tenant_id = v_books_id
      AND (v_search IS NULL OR c.name ILIKE '%' || v_search || '%' OR coalesce(c.code, '') ILIKE '%' || v_search || '%')
    ORDER BY c.name ASC, c.id ASC
    LIMIT v_limit OFFSET v_offset;

  ELSIF p_entity_type = 'courier' THEN
    RETURN QUERY
    SELECT
      cs.wallet_entity_id,
      'courier'::text,
      cs.name,
      upper(cs.code),
      coalesce(nullif(trim(cs.notes), ''), 'Courier service'),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      cs.id,
      coalesce(cs.tenant_id, v_books_id),
      wa.id IS NOT NULL
    FROM public.courier_services cs
    LEFT JOIN public.cashbook_accounts wa
      ON wa.parent_tenant_id = v_books_id AND wa.entity_type = 'courier' AND wa.entity_id = cs.wallet_entity_id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE cs.is_active = true
      AND cs.wallet_entity_id IS NOT NULL
      AND (cs.tenant_id IS NULL OR cs.tenant_id = v_books_id
           OR cs.tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id))
      AND (v_search IS NULL OR cs.name ILIKE '%' || v_search || '%' OR coalesce(cs.code, '') ILIKE '%' || v_search || '%')
    ORDER BY cs.name ASC, cs.wallet_entity_id ASC
    LIMIT v_limit OFFSET v_offset;

  ELSIF p_entity_type = 'investor' THEN
    RETURN QUERY
    SELECT
      i.id, 'investor'::text, i.name, NULL::text,
      nullif(trim(concat_ws(' • ', i.phone, i.email)), ''),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      NULL::uuid, i.tenant_id, wa.id IS NOT NULL
    FROM public.investors i
    LEFT JOIN public.cashbook_accounts wa
      ON wa.parent_tenant_id = v_books_id AND wa.entity_type = 'investor' AND wa.entity_id = i.id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE i.tenant_id = v_books_id
      AND (v_search IS NULL OR i.name ILIKE '%' || v_search || '%')
    ORDER BY i.name ASC, i.id ASC
    LIMIT v_limit OFFSET v_offset;
  END IF;
END;
$$;
