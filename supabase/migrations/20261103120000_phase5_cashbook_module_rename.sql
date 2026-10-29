-- Phase 5 BP2-r: universal_wallet module → cashbook; staff RPC renames.

-- 1) Module key migration
INSERT INTO public.modules (key, name, description, is_active, parent_module_key)
SELECT
  'cashbook',
  coalesce(nullif(trim(m.name), ''), 'Cashbook'),
  m.description,
  m.is_active,
  m.parent_module_key
FROM public.modules m
WHERE m.key = 'universal_wallet'
ON CONFLICT (key) DO UPDATE
SET
  name = EXCLUDED.name,
  description = coalesce(EXCLUDED.description, public.modules.description),
  is_active = EXCLUDED.is_active;

UPDATE public.modules SET parent_module_key = 'cashbook' WHERE parent_module_key = 'universal_wallet';
UPDATE public.module_actions SET module_key = 'cashbook' WHERE module_key = 'universal_wallet';
UPDATE public.tenant_modules SET module_key = 'cashbook' WHERE module_key = 'universal_wallet';
UPDATE public.tenant_role_grants SET module_key = 'cashbook' WHERE module_key = 'universal_wallet';
UPDATE public.membership_grants SET module_key = 'cashbook' WHERE module_key = 'universal_wallet';
UPDATE public.tenant_module_submodules SET parent_module_key = 'cashbook' WHERE parent_module_key = 'universal_wallet';

DELETE FROM public.modules WHERE key = 'universal_wallet';

UPDATE public.modules SET name = 'Cashbook' WHERE key = 'cashbook';

-- 2) New-tenant auto-enable trigger
DROP TRIGGER IF EXISTS trg_auto_enable_universal_wallet ON public.tenants;
DROP TRIGGER IF EXISTS trg_auto_enable_cashbook ON public.tenants;
DROP FUNCTION IF EXISTS public.auto_enable_universal_wallet_for_new_tenant();

-- 3) Rename legacy RPCs when present (fresh replay may already use cashbook names)
DO $rename$
BEGIN
  IF to_regprocedure('public.get_wallet_account_balances(bigint,text,bigint,text)') IS NOT NULL
     AND to_regprocedure('public.get_cashbook_account_balances(bigint,text,bigint,text)') IS NULL THEN
    ALTER FUNCTION public.get_wallet_account_balances(bigint, text, bigint, text) RENAME TO get_cashbook_account_balances;
  END IF;
  IF to_regprocedure('public.get_wallet_dashboard_summary(bigint)') IS NOT NULL
     AND to_regprocedure('public.get_cashbook_dashboard_summary(bigint)') IS NULL THEN
    ALTER FUNCTION public.get_wallet_dashboard_summary(bigint) RENAME TO get_cashbook_dashboard_summary;
  END IF;
  IF to_regprocedure('public.get_wallet_detail_for_staff(bigint,text,bigint,text)') IS NOT NULL
     AND to_regprocedure('public.get_cashbook_detail_for_staff(bigint,text,bigint,text)') IS NULL THEN
    ALTER FUNCTION public.get_wallet_detail_for_staff(bigint, text, bigint, text) RENAME TO get_cashbook_detail_for_staff;
  END IF;
  IF to_regprocedure('public.get_wallet_entity_statement(bigint,text,bigint,timestamp with time zone,timestamp with time zone)') IS NOT NULL
     AND to_regprocedure('public.get_cashbook_entity_statement(bigint,text,bigint,timestamp with time zone,timestamp with time zone)') IS NULL THEN
    ALTER FUNCTION public.get_wallet_entity_statement(bigint, text, bigint, timestamp with time zone, timestamp with time zone)
      RENAME TO get_cashbook_entity_statement;
  END IF;
  IF to_regprocedure('public.list_wallet_entities_for_staff(bigint,text,text,integer,integer,text)') IS NOT NULL
     AND to_regprocedure('public.list_cashbook_entities_for_staff(bigint,text,text,integer,integer,text)') IS NULL THEN
    ALTER FUNCTION public.list_wallet_entities_for_staff(bigint, text, text, integer, integer, text) RENAME TO list_cashbook_entities_for_staff;
  END IF;
  IF to_regprocedure('public.list_wallet_ledger_for_staff(bigint,text,bigint,text,bigint,integer,integer)') IS NOT NULL
     AND to_regprocedure('public.list_cashbook_ledger_for_staff(bigint,text,bigint,text,bigint,integer,integer)') IS NULL THEN
    ALTER FUNCTION public.list_wallet_ledger_for_staff(bigint, text, bigint, text, bigint, integer, integer) RENAME TO list_cashbook_ledger_for_staff;
  END IF;
  IF to_regprocedure('public.record_wallet_manual_transaction_for_staff(bigint,text,text,bigint,numeric,text,numeric,text,text,text,text,text,bigint,text)') IS NOT NULL
     AND to_regprocedure('public.record_cashbook_manual_transaction_for_staff(bigint,text,text,bigint,numeric,text,numeric,text,text,text,text,text,bigint,text)') IS NULL THEN
    ALTER FUNCTION public.record_wallet_manual_transaction_for_staff(
      bigint, text, text, bigint, numeric, text, numeric, text, text, text, text, text, bigint, text
    ) RENAME TO record_cashbook_manual_transaction_for_staff;
  END IF;
  IF to_regprocedure('public.reverse_wallet_ledger_entry_for_staff(bigint,uuid,text,text)') IS NOT NULL
     AND to_regprocedure('public.reverse_cashbook_ledger_entry_for_staff(bigint,uuid,text,text)') IS NULL THEN
    ALTER FUNCTION public.reverse_wallet_ledger_entry_for_staff(bigint, uuid, text, text) RENAME TO reverse_cashbook_ledger_entry_for_staff;
  END IF;
  IF to_regprocedure('public.wallet_books_tenant_id(bigint)') IS NOT NULL
     AND to_regprocedure('public.cashbook_books_tenant_id(bigint)') IS NULL THEN
    ALTER FUNCTION public.wallet_books_tenant_id(bigint) RENAME TO cashbook_books_tenant_id;
  END IF;
  IF to_regprocedure('public.wallet_staff_can_view(bigint)') IS NOT NULL
     AND to_regprocedure('public.cashbook_staff_can_view(bigint)') IS NULL THEN
    ALTER FUNCTION public.wallet_staff_can_view(bigint) RENAME TO cashbook_staff_can_view;
  END IF;
  IF to_regprocedure('public.wallet_staff_can_edit(bigint)') IS NOT NULL
     AND to_regprocedure('public.cashbook_staff_can_edit(bigint)') IS NULL THEN
    ALTER FUNCTION public.wallet_staff_can_edit(bigint) RENAME TO cashbook_staff_can_edit;
  END IF;
END
$rename$;

CREATE OR REPLACE FUNCTION "public"."auto_enable_cashbook_for_new_tenant"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  insert into public.tenant_modules (tenant_id, module_key, is_active)
  values (NEW.id, 'cashbook', true)
  on conflict (tenant_id, module_key) do update set is_active = true;
  return NEW;
end;
$$;


CREATE OR REPLACE FUNCTION "public"."cashbook_staff_can_edit"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT
    public.is_superadmin()
    OR public.membership_has_module_action(public.resolve_parent_tenant_id(p_tenant_id), 'cashbook', 'edit')
    OR public.membership_has_module_action(p_tenant_id, 'cashbook', 'edit')
    OR public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(p_tenant_id));
$$;


CREATE OR REPLACE FUNCTION "public"."cashbook_staff_can_view"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT
    public.is_superadmin()
    OR public.membership_has_module_action(public.resolve_parent_tenant_id(p_tenant_id), 'cashbook', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'cashbook', 'view')
    OR public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(p_tenant_id));
$$;


CREATE OR REPLACE FUNCTION "public"."cashbook_books_tenant_id"("p_tenant_id" bigint) RETURNS bigint
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT public.resolve_parent_tenant_id(p_tenant_id);
$$;


CREATE OR REPLACE FUNCTION "public"."get_cashbook_account_balances"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_currency_code" "text" DEFAULT 'BDT'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_result jsonb;
  v_books_id bigint;
  v_entity_id bigint;
BEGIN
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN
    v_entity_id := v_books_id;
  END IF;

  SELECT jsonb_build_object(
    'parent_tenant_id', v_books_id,
    'tenant_id', v_books_id,
    'entity_type', p_entity_type,
    'entity_id', v_entity_id,
    'currency_code', coalesce(w.currency_code, p_currency_code),
    'available_balance', coalesce(w.available_balance, 0.0000),
    'pending_balance', coalesce(w.pending_balance, 0.0000),
    'locked_balance', coalesce(w.locked_balance, 0.0000),
    'total_balance', (
      coalesce(w.available_balance, 0.0000)
      + coalesce(w.pending_balance, 0.0000)
      + coalesce(w.locked_balance, 0.0000)
    ),
    'account_class', coalesce(w.account_class::text, case when p_entity_type = 'tenant' then 'tenant_asset' else 'profile_custody' end)
  )
  INTO v_result
  FROM (SELECT 1) dummy
  LEFT JOIN public.cashbook_accounts w
    ON w.parent_tenant_id = v_books_id
   AND w.entity_type = p_entity_type
   AND w.entity_id = v_entity_id
   AND w.currency_code = coalesce(p_currency_code, 'BDT');

  RETURN v_result;
END;
$$;


CREATE OR REPLACE FUNCTION "public"."get_cashbook_dashboard_summary"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
  v_tenant_cash numeric(18,4) := 0.0000;
  v_courier_cod_holding numeric(18,4) := 0.0000;
  v_merchant_pending numeric(18,4) := 0.0000;
  v_merchant_available numeric(18,4) := 0.0000;
  v_vendor_payables numeric(18,4) := 0.0000;
  v_customer_deposits numeric(18,4) := 0.0000;
  v_ledger_cash numeric(18,4);
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not (
    public.cashbook_staff_can_view(p_tenant_id)
    or public.membership_has_module_action(v_books_id, 'payments', 'view')
    or public.membership_has_module_action(p_tenant_id, 'payments', 'view')
    or public.is_tenant_staff(p_tenant_id)
  ) then
    return jsonb_build_object(
      'success', false,
      'error', 'access denied',
      'tenant_id', v_books_id,
      'parent_tenant_id', v_books_id,
      'tenant_cash_total', 0,
      'courier_cod_holding_total', 0,
      'merchant_pending_total', 0,
      'merchant_available_total', 0,
      'vendor_payables_total', 0,
      'customer_deposits_total', 0
    );
  end if;

  select coalesce(w.available_balance, 0.0000)
  into v_tenant_cash
  from public.cashbook_accounts w
  where w.parent_tenant_id = v_books_id
    and w.entity_type = 'tenant'
    and w.entity_id = v_books_id
    and w.currency_code = 'BDT'
  limit 1;

  select l.balance_after
  into v_ledger_cash
  from public.cashbook_entries l
  where l.parent_tenant_id = v_books_id
    and l.entity_type = 'tenant'
    and l.entity_id = v_books_id
    and coalesce(l.currency_code, 'BDT') = 'BDT'
  order by l.id desc
  limit 1;

  if coalesce(v_tenant_cash, 0) = 0 and coalesce(v_ledger_cash, 0) <> 0 then
    v_tenant_cash := v_ledger_cash;
  end if;

  select
    coalesce(sum(case when entity_type = 'courier' then pending_balance + available_balance else 0 end), 0),
    coalesce(sum(case when entity_type in ('customer', 'middleman') then pending_balance else 0 end), 0),
    coalesce(sum(case when entity_type in ('customer', 'middleman') then available_balance else 0 end), 0),
    coalesce(sum(case when entity_type = 'vendor' then available_balance else 0 end), 0),
    coalesce(sum(case when entity_type = 'customer' then available_balance else 0 end), 0)
  into
    v_courier_cod_holding,
    v_merchant_pending,
    v_merchant_available,
    v_vendor_payables,
    v_customer_deposits
  from public.cashbook_accounts
  where parent_tenant_id = v_books_id;

  return jsonb_build_object(
    'success', true,
    'tenant_id', v_books_id,
    'parent_tenant_id', v_books_id,
    'tenant_cash_total', coalesce(v_tenant_cash, 0),
    'courier_cod_holding_total', v_courier_cod_holding,
    'merchant_pending_total', v_merchant_pending,
    'merchant_available_total', v_merchant_available,
    'vendor_payables_total', v_vendor_payables,
    'customer_deposits_total', v_customer_deposits
  );
end;
$$;


CREATE OR REPLACE FUNCTION "public"."get_cashbook_detail_for_staff"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_currency_code" "text" DEFAULT 'BDT'::"text") RETURNS "jsonb"
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

  IF NOT public.cashbook_staff_can_view(p_tenant_id) THEN
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

  v_account := public.get_cashbook_account_balances(v_books_id, p_entity_type, v_entity_id, p_currency_code);

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
      'can_record_manual', public.cashbook_staff_can_edit(p_tenant_id),
      'can_reverse', public.cashbook_staff_can_edit(p_tenant_id)
    )
  );
END;
$$;


CREATE OR REPLACE FUNCTION "public"."get_cashbook_entity_statement"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_start_date" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_end_date" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
DECLARE
  v_opening_balance NUMERIC(18,4) := 0.0000;
  v_total_credits NUMERIC(18,4) := 0.0000;
  v_total_debits NUMERIC(18,4) := 0.0000;
  v_closing_balance NUMERIC(18,4) := 0.0000;
  v_entries JSONB;
BEGIN
  IF p_start_date IS NOT NULL THEN
    SELECT COALESCE(
      SUM(CASE WHEN type = 'credit' THEN amount ELSE -amount END),
      0.0000
    )
    INTO v_opening_balance
    FROM cashbook_entries
    WHERE tenant_id = p_tenant_id
      AND entity_type = p_entity_type
      AND entity_id = p_entity_id
      AND created_at < p_start_date;
  END IF;

  SELECT 
    COALESCE(SUM(CASE WHEN type = 'credit' THEN amount ELSE 0 END), 0.0000),
    COALESCE(SUM(CASE WHEN type = 'debit' THEN amount ELSE 0 END), 0.0000)
  INTO v_total_credits, v_total_debits
  FROM cashbook_entries
  WHERE tenant_id = p_tenant_id
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at <= p_end_date);

  v_closing_balance := v_opening_balance + v_total_credits - v_total_debits;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', id,
      'tenant_id', tenant_id,
      'entity_type', entity_type,
      'entity_id', entity_id,
      'type', type,
      'amount', amount,
      'currency_code', currency_code,
      'exchange_rate', exchange_rate,
      'base_amount', base_amount,
      'balance_after', balance_after,
      'source_type', source_type,
      'source_id', source_id,
      'metadata', metadata,
      'created_at', created_at
    ) ORDER BY created_at ASC, id ASC
  ), '[]'::jsonb)
  INTO v_entries
  FROM cashbook_entries
  WHERE tenant_id = p_tenant_id
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at <= p_end_date);

  RETURN jsonb_build_object(
    'tenant_id', p_tenant_id,
    'entity_type', p_entity_type,
    'entity_id', p_entity_id,
    'start_date', p_start_date,
    'end_date', p_end_date,
    'opening_balance', v_opening_balance,
    'total_credits', v_total_credits,
    'total_debits', v_total_debits,
    'closing_balance', v_closing_balance,
    'entries', v_entries
  );
END;
$$;


CREATE OR REPLACE FUNCTION "public"."list_cashbook_entities_for_staff"("p_tenant_id" bigint, "p_entity_type" "text", "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 100, "p_offset" integer DEFAULT 0, "p_currency_code" "text" DEFAULT 'BDT'::"text") RETURNS TABLE("entity_id" bigint, "entity_type" "text", "name" "text", "code" "text", "caption" "text", "available_balance" numeric, "pending_balance" numeric, "locked_balance" numeric, "total_balance" numeric, "source_uuid" "uuid", "operating_tenant_id" bigint, "has_wallet_activity" boolean)
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
  IF NOT public.cashbook_staff_can_view(p_tenant_id) THEN
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


CREATE OR REPLACE FUNCTION "public"."list_cashbook_ledger_for_staff"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_operating_tenant_id" bigint DEFAULT NULL::bigint, "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS TABLE("id" "uuid", "parent_tenant_id" bigint, "operating_tenant_id" bigint, "entity_type" "text", "entity_id" bigint, "type" "text", "amount" numeric, "currency_code" "text", "exchange_rate" numeric, "base_amount" numeric, "balance_after" numeric, "source_type" "text", "source_id" "text", "metadata" "jsonb", "created_at" timestamp with time zone, "is_reversal" boolean, "reversed_entry_id" "uuid", "cashbook_point_id" bigint, "cashbook_point_name" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


CREATE OR REPLACE FUNCTION "public"."record_cashbook_manual_transaction_for_staff"("p_tenant_id" bigint, "p_action_type" "text", "p_primary_entity_type" "text", "p_primary_entity_id" bigint, "p_amount" numeric, "p_currency_code" "text" DEFAULT 'BDT'::"text", "p_exchange_rate" numeric DEFAULT 1.000000, "p_category" "text" DEFAULT NULL::"text", "p_payment_method" "text" DEFAULT NULL::"text", "p_reference_id" "text" DEFAULT NULL::"text", "p_note" "text" DEFAULT NULL::"text", "p_counterparty_entity_type" "text" DEFAULT NULL::"text", "p_counterparty_entity_id" bigint DEFAULT NULL::bigint, "p_target_bucket" "text" DEFAULT 'available'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_operating_id bigint;
  v_source_id text;
  v_meta jsonb;
  v_primary_id bigint;
  v_ledger_ids uuid[] := '{}';
  v_entry jsonb;
  v_primary_entity_id bigint;
  v_counterparty_id bigint;
BEGIN
  IF NOT public.cashbook_staff_can_edit(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  IF coalesce(p_amount, 0) <= 0 OR coalesce(p_exchange_rate, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'amount and exchange_rate must be positive');
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_operating_id := p_tenant_id;
  v_primary_entity_id := p_primary_entity_id;
  IF p_primary_entity_type = 'tenant' THEN v_primary_entity_id := v_books_id; END IF;

  v_source_id := coalesce(nullif(trim(p_reference_id), ''),
    CASE p_action_type
      WHEN 'pay' THEN 'MAN-PAY-' || gen_random_uuid()::text
      WHEN 'withdraw' THEN 'MAN-WD-' || gen_random_uuid()::text
      WHEN 'deposit' THEN 'MAN-DEP-' || gen_random_uuid()::text
      ELSE 'MAN-CR-' || gen_random_uuid()::text
    END);

  v_meta := jsonb_build_object(
    'section', p_category,
    'method', p_payment_method,
    'trx_id', v_source_id,
    'note', p_note,
    'action_type', p_action_type,
    'transaction_type', 'manual_adjustment',
    'label', initcap(p_action_type),
    'recorded_by', public.current_user_email(),
    'target_bucket', coalesce(p_target_bucket, 'available')
  );

  IF p_action_type IN ('pay', 'credit') AND p_primary_entity_type = 'tenant'
     AND (p_counterparty_entity_type IS NULL OR p_counterparty_entity_id IS NULL) THEN
    RETURN jsonb_build_object('success', false, 'error', 'counterparty required');
  END IF;

  IF p_action_type = 'deposit' THEN
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_primary_entity_type, v_primary_entity_id,
      'credit', p_amount, p_currency_code, p_exchange_rate,
      'adjustment', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSIF p_action_type = 'withdraw' THEN
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_primary_entity_type, v_primary_entity_id,
      'debit', p_amount, p_currency_code, p_exchange_rate,
      'payout', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSIF p_action_type = 'credit' AND p_primary_entity_type = 'tenant' THEN
    v_counterparty_id := p_counterparty_entity_id;
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_counterparty_entity_type, v_counterparty_id,
      'credit', p_amount, p_currency_code, p_exchange_rate,
      'adjustment', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSIF p_action_type = 'credit' THEN
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_primary_entity_type, v_primary_entity_id,
      'credit', p_amount, p_currency_code, p_exchange_rate,
      'adjustment', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSIF p_action_type = 'pay' AND p_primary_entity_type = 'tenant' THEN
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, 'tenant', v_books_id,
      'debit', p_amount, p_currency_code, p_exchange_rate,
      CASE WHEN p_category = 'vendor_purchase' THEN 'vendor_purchase' ELSE 'adjustment' END,
      v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_counterparty_entity_type, p_counterparty_entity_id,
      'credit', p_amount, p_currency_code, p_exchange_rate,
      CASE WHEN p_category = 'vendor_purchase' THEN 'vendor_purchase' ELSE 'adjustment' END,
      v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSIF p_action_type = 'pay' THEN
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, 'tenant', v_books_id,
      'debit', p_amount, p_currency_code, p_exchange_rate,
      'adjustment', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_primary_entity_type, v_primary_entity_id,
      'credit', p_amount, p_currency_code, p_exchange_rate,
      'adjustment', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'invalid action_type');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'ledger_entry_ids', to_jsonb(v_ledger_ids),
    'primary_account', public.get_cashbook_account_balances(v_books_id, p_primary_entity_type, v_primary_entity_id, p_currency_code)
  );
END;
$$;


CREATE OR REPLACE FUNCTION "public"."reverse_cashbook_ledger_entry_for_staff"("p_tenant_id" bigint, "p_ledger_entry_id" "uuid", "p_reason" "text", "p_reference_id" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_orig public.cashbook_entries%ROWTYPE;
  v_reversal_type text;
  v_reversal_id uuid;
  v_meta jsonb;
  v_entry jsonb;
BEGIN
  IF NOT public.cashbook_staff_can_edit(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  IF nullif(trim(p_reason), '') IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'reason required');
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  SELECT * INTO v_orig FROM public.cashbook_entries WHERE id = p_ledger_entry_id;
  IF v_orig.id IS NULL OR v_orig.parent_tenant_id <> v_books_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'entry not found');
  END IF;

  IF v_orig.metadata ? 'reversed_by' OR v_orig.metadata ? 'reversal_of' THEN
    RETURN jsonb_build_object('success', false, 'error', 'entry already reversed or is a reversal');
  END IF;

  IF v_orig.source_type = 'shop_order' AND NOT coalesce((v_orig.metadata->>'allow_manual_reversal')::boolean, false)
     AND NOT public.is_superadmin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'system shop_order entries cannot be reversed');
  END IF;

  v_reversal_type := CASE WHEN v_orig.type = 'credit' THEN 'debit' ELSE 'credit' END;
  v_meta := jsonb_build_object(
    'reversal_of', v_orig.id::text,
    'transaction_type', 'manual_reversal',
    'note', p_reason,
    'trx_id', coalesce(p_reference_id, 'REV-' || gen_random_uuid()::text),
    'recorded_by', public.current_user_email()
  );

  v_entry := public.record_ledger_transaction(
    v_orig.parent_tenant_id,
    v_orig.operating_tenant_id,
    v_orig.entity_type,
    v_orig.entity_id,
    v_reversal_type,
    v_orig.amount,
    v_orig.currency_code,
    v_orig.exchange_rate,
    v_orig.source_type,
    coalesce(p_reference_id, v_orig.source_id),
    v_meta,
    coalesce(v_orig.metadata->>'target_bucket', 'available'),
    false
  );
  v_reversal_id := (v_entry->>'id')::uuid;

  UPDATE public.cashbook_entries
  SET metadata = metadata || jsonb_build_object('reversed_by', v_reversal_id::text)
  WHERE id = v_orig.id;

  RETURN jsonb_build_object(
    'success', true,
    'reversal_entry_id', v_reversal_id,
    'account', public.get_cashbook_account_balances(
      v_books_id, v_orig.entity_type, v_orig.entity_id, v_orig.currency_code
    )
  );
END;
$$;


-- Refresh treasury report module gate
CREATE OR REPLACE FUNCTION "public"."get_tenant_cash_in_report"("p_tenant_id" bigint, "p_start_date" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_end_date" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
  v_cash_in numeric(18,4) := 0.0000;
  v_count integer := 0;
  v_by_method jsonb;
  v_entries jsonb;
begin
  if p_tenant_id is null then
    raise exception 'Tenant ID is required';
  end if;

  select coalesce(t.parent_id, t.id)
  into v_books_id
  from public.tenants t
  where t.id = p_tenant_id;

  if v_books_id is null then
    raise exception 'Tenant not found';
  end if;

  if not (
    public.membership_has_module_action(p_tenant_id, 'cashbook', 'view')
    or public.membership_has_module_action(v_books_id, 'cashbook', 'view')
  ) then
    raise exception 'Not authorized';
  end if;

  with receipt_invoice as (
    select
      ip.payment_id,
      min(ip.global_invoice_id) as invoice_id
    from public.pay_allocations ip
    group by ip.payment_id
  ),
  receipt_lines as (
    select
      gp.id as payment_id,
      gp.id::text || '-' || coalesce(gpi.id::text, 'h') as line_id,
      coalesce(gpi.amount, gp.amount) as amount,
      case
        when gp.collection_source = 'recipient'::public.collection_source_type then 'courier_remittance'
        else 'buyer_receipt'
      end as source_type,
      gp.id::text as source_id,
      nullif(trim(gp.note), '') as label,
      ri.invoice_id,
      gp.created_at,
      coalesce(gpi.payment_method_code, nullif(trim(gp.method::text), ''), 'other') as method,
      gpi.reference as instrument_reference,
      gpi.cheque_number,
      bb.name as bank_name
    from public.pays gp
    left join public.pay_instruments gpi on gpi.payment_id = gp.id
    left join public.bd_banks bb on bb.id = gpi.bd_bank_id
    left join receipt_invoice ri on ri.payment_id = gp.id
    where gp.tenant_id = v_books_id
      and gp.voided_at is null
      and coalesce(gp.method::text, '') <> 'wallet_credit'
      and (p_start_date is null or coalesce(gp.payment_date::timestamptz, gp.created_at) >= p_start_date)
      and (p_end_date is null or coalesce(gp.payment_date::timestamptz, gp.created_at) <= p_end_date)
  ),
  lined as (
    select distinct on (line_id)
      line_id as id,
      amount,
      source_type,
      source_id,
      case
        when bank_name is not null and cheque_number is not null then
          coalesce(label, '') || ' Cheque ' || cheque_number || ' @ ' || bank_name
        when instrument_reference is not null then coalesce(label, instrument_reference)
        else label
      end as label,
      invoice_id,
      created_at,
      method
    from receipt_lines
    order by line_id, amount desc
  )
  select
    coalesce(sum(amount), 0.0000),
    count(*)::integer,
    coalesce(
      (
        select jsonb_agg(jsonb_build_object(
          'method', m.method,
          'amount', m.amt,
          'count', m.cnt
        ) order by m.amt desc)
        from (
          select method, sum(amount) as amt, count(*)::integer as cnt
          from lined
          group by method
        ) m
      ),
      '[]'::jsonb
    ),
    coalesce(
      (
        select jsonb_agg(jsonb_build_object(
          'id', e.id,
          'amount', e.amount,
          'method', e.method,
          'source_type', e.source_type,
          'source_id', e.source_id,
          'label', e.label,
          'invoice_id', e.invoice_id,
          'created_at', e.created_at
        ) order by e.created_at desc, e.id desc)
        from lined e
      ),
      '[]'::jsonb
    )
  into v_cash_in, v_count, v_by_method, v_entries
  from lined;

  return jsonb_build_object(
    'tenant_id', v_books_id,
    'start_date', p_start_date,
    'end_date', p_end_date,
    'cash_in_total', v_cash_in,
    'entry_count', v_count,
    'by_method', v_by_method,
    'entries', v_entries
  );
end;
$$;

CREATE TRIGGER trg_auto_enable_cashbook
  AFTER INSERT ON public.tenants
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_enable_cashbook_for_new_tenant();
