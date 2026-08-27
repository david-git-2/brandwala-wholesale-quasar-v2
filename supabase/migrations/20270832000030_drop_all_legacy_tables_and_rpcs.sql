-- ==============================================================================
-- MASTER CLEANUP MIGRATION: DROP ALL LEGACY TABLES, RPCS, TRIGGERS & SEQUENCES
-- ==============================================================================
-- Referenced in:
--   - doc/LEGACY_TABLES_AUDIT.md
--   - doc/LEGACY_RPCS_AUDIT.md
--
-- Excluded Domains:
--   - Thrift module is completely preserved and excluded from deletion.
--   - Courier remittance infrastructure is active and preserved.
--
-- This migration safely decouples active procedures and permanently drops:
-- 1. Legacy Wholesale & Dropship Orders (orders, order_items, commerce_*)
-- 2. Legacy Carts (carts, cart_items, commerce_cart)
-- 3. Legacy Vendor Stores (stores, store_access, store_product_prices)
-- 4. Legacy Invoices (invoices, invoice_items, invoice_boxes, commerce_invoices)
-- 5. Legacy Promotion Rules (gift_rules, gift_rule_items, gift_rule_redemptions)
-- 6. Legacy Contact & Financial Entities (business_parties, investor_balances)
-- 7. All corresponding legacy RPCs, triggers, sequences, and deprecated enums.
-- ==============================================================================

BEGIN;

-- ==============================================================================
-- 1. DECOUPLE ACTIVE RPCS FROM LEGACY SCHEMAS
-- ==============================================================================

-- 1A. list_child_procurement_lines: removes legacy public.order_items / public.orders union
CREATE OR REPLACE FUNCTION "public"."list_child_procurement_lines"(
  "p_parent_tenant_id" bigint, 
  "p_child_tenant_id" bigint DEFAULT NULL::bigint, 
  "p_search" "text" DEFAULT NULL::"text", 
  "p_limit" integer DEFAULT 100, 
  "p_offset" integer DEFAULT 0
) RETURNS TABLE(
  "source_type" "text", 
  "source_id" bigint, 
  "child_tenant_id" bigint, 
  "child_tenant_name" "text", 
  "name" "text", 
  "product_id" bigint, 
  "quantity" integer, 
  "cost_bdt" numeric, 
  "price_gbp" numeric, 
  "image_url" "text", 
  "barcode" "text", 
  "product_code" "text", 
  "reference_label" "text"
)
LANGUAGE "plpgsql" STABLE SECURITY DEFINER
SET "search_path" TO 'public'
AS $$
BEGIN
  IF NOT public.user_can_manage_parent_tenant(p_parent_tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  RETURN QUERY
  (
    SELECT
      'costing_item'::text AS source_type,
      pci.id AS source_id,
      pcf.tenant_id AS child_tenant_id,
      t.name AS child_tenant_name,
      pci.name,
      pci.product_id,
      greatest(coalesce(pci.confirmed_quantity, pci.quantity::integer, 0), 0)::integer AS quantity,
      pci.offer_price AS cost_bdt,
      pci.price_gbp,
      pci.image_url,
      pci.barcode,
      pci.product_code,
      ('Costing #' || pcf.id::text || ' — ' || coalesce(pcf.name, 'Untitled')) AS reference_label
    FROM public.product_based_costing_items pci
    INNER JOIN public.product_based_costing_files pcf ON pcf.id = pci.product_based_costing_file_id
    INNER JOIN public.tenants t ON t.id = pcf.tenant_id
    WHERE t.parent_id = p_parent_tenant_id
      AND (p_child_tenant_id IS NULL OR pcf.tenant_id = p_child_tenant_id)
      AND pcf.status = 'ready_for_shipment'
      AND pci.assigned_shipment_id IS NULL
      AND pci.product_id IS NOT NULL
      AND coalesce(pci.confirmed_quantity, pci.quantity::integer, 0) > 0
      AND (
        p_search IS NULL OR trim(p_search) = ''
        OR pci.name ILIKE '%' || trim(p_search) || '%'
        OR pcf.name ILIKE '%' || trim(p_search) || '%'
      )
  )
  UNION ALL
  (
    SELECT
      'shop_order_item'::text AS source_type,
      oi.id AS source_id,
      o.tenant_id AS child_tenant_id,
      t.name AS child_tenant_name,
      oi.name,
      oi.product_id,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer AS quantity,
      CASE WHEN gc.code = 'BDT' THEN oi.final_price_amount ELSE NULL::numeric END AS cost_bdt,
      CASE WHEN gc.code = 'GBP' THEN oi.final_price_amount ELSE NULL::numeric END AS price_gbp,
      oi.image_url,
      p.barcode,
      p.product_code,
      ('Shop Order #' || o.order_no || ' — ' || o.name) AS reference_label
    FROM public.shop_order_items oi
    INNER JOIN public.shop_orders o ON o.id = oi.order_id
    INNER JOIN public.tenants t ON t.id = o.tenant_id
    LEFT JOIN public.products p ON p.id = oi.product_id
    LEFT JOIN public.global_currencies gc ON gc.id = oi.final_price_currency_id
    WHERE o.status = 'placed'
      AND oi.procurement_pulled = false
      AND o.shop_type_snapshot = 'vendor_catalog'
      AND t.parent_id = p_parent_tenant_id
      AND (p_child_tenant_id IS NULL OR o.tenant_id = p_child_tenant_id)
      AND (
        p_search IS NULL OR trim(p_search) = ''
        OR oi.name ILIKE '%' || trim(p_search) || '%'
        OR o.name ILIKE '%' || trim(p_search) || '%'
      )
  )
  ORDER BY child_tenant_name, source_type, source_id
  LIMIT greatest(coalesce(p_limit, 100), 1)
  OFFSET greatest(coalesce(p_offset, 0), 0);
END;
$$;

-- 1B. get_dropship_wallet_reconciliation_report: removes gift_rule_redemptions query
CREATE OR REPLACE FUNCTION "public"."get_dropship_wallet_reconciliation_report"("p_tenant_id" bigint DEFAULT NULL::bigint) 
RETURNS "jsonb"
LANGUAGE "plpgsql" STABLE SECURITY DEFINER
SET "search_path" TO 'public'
AS $$
declare
  v_target_tenant_id bigint;
  v_missing_invoice_billed bigint := 0;
  v_missing_courier_remittance bigint := 0;
  v_missing_return_compensation bigint := 0;
  v_mixed_customer_profit bigint := 0;
  v_uncanonicalized_source_ids bigint := 0;
  v_conflicting_active_offers bigint := 0;
  v_missing_or_duplicate_gifts bigint := 0;
begin
  if p_tenant_id is not null then
    v_target_tenant_id := p_tenant_id;
  else
    v_target_tenant_id := public.current_tenant_id();
  end if;

  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where (v_target_tenant_id is null or m.tenant_id = v_target_tenant_id)
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Admin or Staff role required for reconciliation report';
  end if;

  -- 1. Posted dropship invoices missing invoice_billed (P0A contract)
  select count(*) into v_missing_invoice_billed
  from public.global_invoices i
  where i.invoice_type = 'dropship'
    and i.invoice_status = 'posted'
    and i.billing_profile_id is not null
    and i.total_amount > 0
    and (v_target_tenant_id is null or i.tenant_id = v_target_tenant_id)
    and not exists (
      select 1 from public.universal_wallet_ledger u
      where u.tenant_id = i.tenant_id
        and u.entity_type = 'customer'
        and u.entity_id = i.billing_profile_id
        and u.source_type = 'shop_order'
        and u.metadata->>'transaction_type' = 'invoice_billed'
        and (u.metadata->>'invoice_id' = i.id::text or u.source_id = i.invoice_no)
    );

  -- 2. Remitted shop orders missing courier remittance UWL entry
  select count(*) into v_missing_courier_remittance
  from public.shop_orders o
  where o.shop_type_snapshot = 'dropship'
    and o.status = 'payment_received'
    and o.courier_remittance_ref is not null
    and (v_target_tenant_id is null or o.tenant_id = v_target_tenant_id)
    and not exists (
      select 1 from public.universal_wallet_ledger u
      where u.tenant_id = o.tenant_id
        and u.entity_type = 'courier'
        and u.source_type = 'shop_order'
        and u.source_id = o.id::text
        and u.metadata->>'purpose' = 'courier_remittance'
    );

  -- 3. Finalized returns missing return compensating UWL entry
  select count(*) into v_missing_return_compensation
  from public.shop_orders o
  where o.shop_type_snapshot = 'dropship'
    and o.status = 'returned'
    and (v_target_tenant_id is null or o.tenant_id = v_target_tenant_id)
    and not exists (
      select 1 from public.universal_wallet_ledger u
      where u.tenant_id = o.tenant_id
        and u.source_type = 'shop_order'
        and u.source_id = o.id::text
        and (
          u.metadata->>'purpose' = 'dropship_return_finalize'
          or u.metadata->>'transaction_type' in (
            'return_reversal',
            'return_profit_clawback',
            'return_revenue_reversal'
          )
        )
    );

  -- 4. Mixed customer vs middleman profit rows
  select count(*) into v_mixed_customer_profit
  from public.universal_wallet_ledger u
  where u.entity_type = 'customer'
    and u.source_type = 'shop_order'
    and u.metadata->>'transaction_type' = 'dropship_profit'
    and (v_target_tenant_id is null or u.tenant_id = v_target_tenant_id);

  -- 5. Uncanonicalized source_ids (order_no instead of order_id string), exclude invoice_billed
  select count(*) into v_uncanonicalized_source_ids
  from public.universal_wallet_ledger u
  join public.shop_orders o on o.tenant_id = u.tenant_id and o.order_no = u.source_id
  where u.source_type = 'shop_order'
    and coalesce(u.metadata->>'transaction_type', '') <> 'invoice_billed'
    and (v_target_tenant_id is null or u.tenant_id = v_target_tenant_id);

  -- 6. Conflicting active offer prices (P2 shop_product_offers)
  select count(*) into v_conflicting_active_offers
  from (
    select shop_id, product_id, condition_bucket
    from public.shop_product_offers
    where is_active = true
    group by shop_id, product_id, condition_bucket
    having count(*) > 1
  ) t;

  -- 7. Legacy gift rules removed - drift is 0
  v_missing_or_duplicate_gifts := 0;

  return jsonb_build_object(
    'reconciliation_time', now(),
    'tenant_id', v_target_tenant_id,
    'healthy', (
      v_missing_invoice_billed = 0 and
      v_missing_courier_remittance = 0 and
      v_missing_return_compensation = 0 and
      v_mixed_customer_profit = 0 and
      v_uncanonicalized_source_ids = 0 and
      v_conflicting_active_offers = 0 and
      v_missing_or_duplicate_gifts = 0
    ),
    'drift_counts', jsonb_build_object(
      'missing_invoice_billed', v_missing_invoice_billed,
      'missing_courier_remittance', v_missing_courier_remittance,
      'missing_return_compensation', v_missing_return_compensation,
      'mixed_customer_profit', v_mixed_customer_profit,
      'uncanonicalized_source_ids', v_uncanonicalized_source_ids,
      'conflicting_active_offers', v_conflicting_active_offers,
      'missing_or_duplicate_gifts', v_missing_or_duplicate_gifts
    )
  );
end;
$$;

-- 1C. create_billing_profile_payment_with_allocations: strictly allocates to global_invoices
CREATE OR REPLACE FUNCTION "public"."create_billing_profile_payment_with_allocations"(
  "p_tenant_id" bigint, 
  "p_billing_profile_id" bigint, 
  "p_amount" numeric, 
  "p_payment_date" "date", 
  "p_method" "text", 
  "p_reference" "text", 
  "p_note" "text", 
  "p_allocations" "jsonb"
) RETURNS "public"."global_payments"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO 'public'
AS $$
declare
  v_payment public.global_payments;
  v_alloc jsonb;
  v_global_invoice_id bigint;
  v_alloc_amount numeric(12,2);
  v_total_alloc numeric(12,2) := 0;
  v_invoice record;
begin
  if p_tenant_id is null or p_billing_profile_id is null then
    raise exception 'Tenant and billing profile are required.';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Payment amount must be greater than zero.';
  end if;

  insert into public.global_payments (
    tenant_id,
    billing_profile_id,
    amount,
    unallocated_amount,
    payment_date,
    method,
    reference,
    note
  )
  values (
    p_tenant_id,
    p_billing_profile_id,
    p_amount,
    p_amount,
    coalesce(p_payment_date, current_date),
    p_method,
    p_reference,
    p_note
  )
  returning * into v_payment;

  if jsonb_typeof(coalesce(p_allocations, '[]'::jsonb)) <> 'array' then
    raise exception 'Allocations must be an array.';
  end if;

  for v_alloc in select * from jsonb_array_elements(coalesce(p_allocations, '[]'::jsonb))
  loop
    v_global_invoice_id := nullif(v_alloc->>'global_invoice_id', '')::bigint;
    v_alloc_amount := coalesce((v_alloc->>'amount')::numeric, 0.00);

    if v_alloc_amount <= 0.00 then continue; end if;

    if v_global_invoice_id is not null then
      select id, tenant_id, billing_profile_id, total_amount, paid_amount, collection_source
      into v_invoice
      from public.global_invoices where id = v_global_invoice_id for update;

      if not found then raise exception 'Global invoice % not found.', v_global_invoice_id; end if;
      if v_invoice.tenant_id <> p_tenant_id then raise exception 'Invoice tenant mismatch.'; end if;
      if coalesce(v_invoice.billing_profile_id, 0) <> p_billing_profile_id then
        raise exception 'Invoice does not belong to billing profile.';
      end if;

      insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
      values (p_tenant_id, v_payment.id, v_global_invoice_id, v_alloc_amount);

      update public.global_invoices
      set paid_amount = coalesce(paid_amount, 0.00) + v_alloc_amount, updated_at = now()
      where id = v_global_invoice_id;

      perform public.recompute_global_invoice_payment_status(v_global_invoice_id);
    end if;

    v_total_alloc := v_total_alloc + v_alloc_amount;
  end loop;

  if v_total_alloc > p_amount then
    raise exception 'Total allocation exceeds payment amount.';
  end if;

  update public.global_payments
  set unallocated_amount = p_amount - v_total_alloc
  where id = v_payment.id
  returning * into v_payment;

  -- Universal Wallet 1: Credit Tenant Cash Available (money received)
  perform public.record_ledger_transaction(
    p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'sales_invoice',
    p_source_id => v_payment.id::text,
    p_metadata => jsonb_build_object(
      'section', 'payments',
      'purpose', 'tenant_payment_received',
      'transaction_type', 'payment_received',
      'label', 'Payment Received',
      'payment_id', v_payment.id,
      'billing_profile_id', p_billing_profile_id,
      'reference', p_reference
    )
  );

  -- Universal Wallet 2: Credit Customer Available (reduces Accounts Receivable)
  perform public.record_ledger_transaction(
    p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'customer',
    p_entity_id => p_billing_profile_id,
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'sales_invoice',
    p_source_id => v_payment.id::text,
    p_metadata => jsonb_build_object(
      'section', 'payments',
      'purpose', 'customer_ar_reduction',
      'transaction_type', 'payment_received',
      'label', 'Payment Applied',
      'payment_id', v_payment.id,
      'reference', p_reference
    )
  );

  return v_payment;
end;
$$;


-- ==============================================================================
-- 2. DROP FOREIGN KEYS LINKED FROM ACTIVE TABLES (IF THEY EXIST)
-- ==============================================================================
ALTER TABLE IF EXISTS public.shipment_items 
    DROP CONSTRAINT IF EXISTS shipment_items_order_id_fkey;

ALTER TABLE IF EXISTS public.invoice_payments 
    DROP CONSTRAINT IF EXISTS payment_allocations_commerce_invoice_id_fkey;

ALTER TABLE IF EXISTS public.invoice_payments 
    DROP CONSTRAINT IF EXISTS payment_allocations_invoice_id_fkey;


-- ==============================================================================
-- 3. DROP OBSOLETE TRIGGERS SAFELY (USING REGCLASS CHECKS)
-- ==============================================================================
DO $$
BEGIN
  IF to_regclass('public.shipment_investments') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_sync_investor_balance_shipments ON public.shipment_investments;
  END IF;
  IF to_regclass('public.stores') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_stores_sync_vendor_reference_fields ON public.stores;
  END IF;
END $$;


-- ==============================================================================
-- 4. DROP ALL STANDALONE LEGACY RPCS DYNAMICALLY (HANDLES ALL OVERLOADS)
-- ==============================================================================
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT p.oid::regprocedure AS func_signature
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname IN (
        -- Wholesale Orders
        'bulk_update_order_items',
        'bulk_update_order_item_offers',
        'assign_order_tenant_fields',
        'set_order_parent_tenant_id',
        -- Commerce & Dropship
        'place_commerce_order',
        'add_item_to_commerce_cart',
        'list_commerce_global_stock_for_store',
        'fn_recalculate_commerce_invoice_totals',
        'refresh_commerce_inventory_product_summaries',
        'refresh_commerce_inventory_product_summary_single',
        'sync_commerce_summary_from_inventory_items',
        'sync_commerce_summary_from_inventory_stocks',
        'create_commerce_invoice',
        'add_commerce_invoice_item',
        'update_commerce_invoice_charges',
        'update_commerce_invoice_item_transactional',
        'assign_commerce_order_item_inventory_transactional',
        'unassign_commerce_order_item_inventory_transactional',
        'remove_commerce_invoice_item_transactional',
        'delete_commerce_invoice_transactional',
        'fn_sync_commerce_invoice_charges_to_accounting',
        'fn_sync_commerce_accounting_entry',
        'trg_fn_commerce_accounting_instead_of',
        'trg_fn_sync_commerce_invoice_payment_status',
        'trg_fn_spread_commerce_invoice_discount',
        -- Carts
        'add_item_to_cart',
        'get_cart',
        'get_cart_details',
        'can_access_cart',
        'can_access_cart_item',
        'can_insert_cart',
        'can_insert_cart_item',
        'cart_exists',
        -- Stores
        'create_store',
        'create_store_access',
        'delete_store_access',
        'update_store_access',
        'update_store_access_fields',
        'check_store_price_access',
        'can_manage_store',
        'get_stores_admin',
        'get_stores_for_customer',
        'get_stores_for_customer_v2',
        'get_store_access_admin_v2',
        'get_store_product_brands',
        'get_store_product_categories',
        'list_store_products',
        'list_store_products_inventory_aggregated',
        -- Invoices
        'list_invoices_paginated',
        'fn_recalculate_normal_invoice_totals',
        'add_payment_allocation',
        'update_payment_allocation_amount',
        -- Investor Balances
        'refresh_investor_balance',
        'sync_investor_balance_from_investors',
        'sync_investor_balance_from_transactions',
        'sync_investor_balance_from_shipment_investments'
      )
  )
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || r.func_signature || ' CASCADE';
  END LOOP;
END $$;


-- ==============================================================================
-- 5. DROP ALL LEGACY TABLES (WITH CASCADE)
-- ==============================================================================

-- 5A. Dropship & Commerce Tables
DROP TABLE IF EXISTS public.commerce_invoice_boxes CASCADE;
DROP TABLE IF EXISTS public.commerce_invoices CASCADE;
DROP TABLE IF EXISTS public.commerce_order_items CASCADE;
DROP TABLE IF EXISTS public.commerce_cart CASCADE;
DROP TABLE IF EXISTS public.commerce_order_settings CASCADE;
DROP TABLE IF EXISTS public.commerce_inventory_product_summaries CASCADE;
DROP TABLE IF EXISTS public.commerce_orders CASCADE;

-- 5B. Wholesale Orders Tables
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;

-- 5C. Shopping Cart Tables
DROP TABLE IF EXISTS public.cart_items CASCADE;
DROP TABLE IF EXISTS public.carts CASCADE;

-- 5D. Vendor Store Tables
DROP TABLE IF EXISTS public.store_product_prices CASCADE;
DROP TABLE IF EXISTS public.store_access CASCADE;
DROP TABLE IF EXISTS public.stores CASCADE;

-- 5E. Invoicing Tables
DROP TABLE IF EXISTS public.invoice_boxes CASCADE;
DROP TABLE IF EXISTS public.invoice_items CASCADE;
DROP TABLE IF EXISTS public.invoices CASCADE;

-- 5F. Promotion & Gift Tables
DROP TABLE IF EXISTS public.gift_rule_redemptions CASCADE;
DROP TABLE IF EXISTS public.gift_rule_items CASCADE;
DROP TABLE IF EXISTS public.gift_rules CASCADE;

-- 5G. Contact & Balance Tables
DROP TABLE IF EXISTS public.business_parties CASCADE;
DROP TABLE IF EXISTS public.investor_balances CASCADE;


-- ==============================================================================
-- 6. DROP ORPHANED SEQUENCES
-- ==============================================================================
DROP SEQUENCE IF EXISTS public.commerce_cart_id_seq CASCADE;
DROP SEQUENCE IF EXISTS public.commerce_inventory_product_summaries_id_seq CASCADE;
DROP SEQUENCE IF EXISTS public.commerce_invoice_boxes_id_seq CASCADE;
DROP SEQUENCE IF EXISTS public.commerce_invoices_id_seq CASCADE;
DROP SEQUENCE IF EXISTS public.commerce_order_items_id_seq CASCADE;
DROP SEQUENCE IF EXISTS public.commerce_orders_id_seq CASCADE;

DROP SEQUENCE IF EXISTS public.orders_id_seq CASCADE;
DROP SEQUENCE IF EXISTS public.order_items_id_seq CASCADE;

DROP SEQUENCE IF EXISTS public.carts_id_seq CASCADE;
DROP SEQUENCE IF EXISTS public.cart_items_id_seq CASCADE;

DROP SEQUENCE IF EXISTS public.stores_id_seq CASCADE;
DROP SEQUENCE IF EXISTS public.store_access_id_seq CASCADE;
DROP SEQUENCE IF EXISTS public.store_product_prices_id_seq CASCADE;

DROP SEQUENCE IF EXISTS public.invoices_id_seq CASCADE;
DROP SEQUENCE IF EXISTS public.invoice_items_id_seq CASCADE;
DROP SEQUENCE IF EXISTS public.invoice_boxes_id_seq CASCADE;

DROP SEQUENCE IF EXISTS public.gift_rules_id_seq CASCADE;
DROP SEQUENCE IF EXISTS public.gift_rule_items_id_seq CASCADE;
DROP SEQUENCE IF EXISTS public.gift_rule_redemptions_id_seq CASCADE;

DROP SEQUENCE IF EXISTS public.business_parties_id_seq CASCADE;
DROP SEQUENCE IF EXISTS public.investor_balances_id_seq CASCADE;


-- ==============================================================================
-- 7. DROP UNUSED ENUMS
-- ==============================================================================
DROP TYPE IF EXISTS public.commerce_order_status CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;

COMMIT;
