-- ==============================================================================
-- MIGRATION: TENANT OPERATIONAL DATA PURGE & RESET ENGINE
-- ==============================================================================
-- Provides atomic, transactional purge capability for Parent Tenants to clear
-- volatile operational rows (stocks, shipments, invoices, orders, carts, ledgers)
-- while preserving master data (products, categories, locations, vendors, users).
-- ==============================================================================

BEGIN;

-- 1. AUDIT LOG TABLE
CREATE TABLE IF NOT EXISTS "public"."tenant_data_purge_logs" (
    "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "parent_tenant_id" BIGINT NOT NULL REFERENCES "public"."tenants"("id") ON DELETE CASCADE,
    "target_tenant_id" BIGINT NOT NULL REFERENCES "public"."tenants"("id") ON DELETE CASCADE,
    "scope" TEXT NOT NULL CHECK ("scope" IN ('all_hierarchy', 'child_only')),
    "executed_by" UUID REFERENCES auth.users("id"),
    "executor_email" TEXT NOT NULL,
    "confirmation_phrase" TEXT NOT NULL,
    "deleted_counts" JSONB NOT NULL DEFAULT '{}'::jsonb,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS "idx_tenant_data_purge_logs_parent" ON "public"."tenant_data_purge_logs"("parent_tenant_id");
CREATE INDEX IF NOT EXISTS "idx_tenant_data_purge_logs_target" ON "public"."tenant_data_purge_logs"("target_tenant_id");

ALTER TABLE "public"."tenant_data_purge_logs" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tenant_data_purge_logs_select" ON "public"."tenant_data_purge_logs"
    FOR SELECT TO "authenticated"
    USING (
        "public"."is_superadmin"() OR
        "public"."user_can_manage_parent_tenant"("parent_tenant_id")
    );


-- 2. RPC: PREVIEW TENANT DATA PURGE
CREATE OR REPLACE FUNCTION "public"."preview_tenant_data_purge"(
    "p_parent_tenant_id" BIGINT,
    "p_scope" TEXT DEFAULT 'all_hierarchy'::TEXT,
    "p_target_child_id" BIGINT DEFAULT NULL::BIGINT
)
RETURNS JSONB
LANGUAGE "plpgsql"
STABLE
SECURITY DEFINER
SET "search_path" TO 'public'
AS $$
DECLARE
    v_target_tenant_ids BIGINT[];
    v_shipment_count BIGINT := 0;
    v_stock_count BIGINT := 0;
    v_invoice_count BIGINT := 0;
    v_order_count BIGINT := 0;
    v_cart_count BIGINT := 0;
    v_ledger_count BIGINT := 0;
    v_wallets_count BIGINT := 0;
BEGIN
    -- Authorization check
    IF NOT (public.is_superadmin() OR public.user_can_manage_parent_tenant(p_parent_tenant_id)) THEN
        RAISE EXCEPTION 'Unauthorized: Only parent tenant administrators can preview data purges.';
    END IF;

    -- Resolve target tenant IDs
    IF p_scope = 'all_hierarchy' THEN
        SELECT array_agg(id) INTO v_target_tenant_ids
        FROM public.tenants
        WHERE id = p_parent_tenant_id OR parent_id = p_parent_tenant_id;

        SELECT count(*) INTO v_shipment_count FROM public.global_shipments WHERE parent_tenant_id = p_parent_tenant_id;
        SELECT count(*) INTO v_stock_count FROM public.global_stocks WHERE parent_tenant_id = p_parent_tenant_id;
        SELECT count(*) INTO v_invoice_count FROM public.global_invoices WHERE parent_tenant_id = p_parent_tenant_id;
        SELECT count(*) INTO v_ledger_count FROM public.universal_ledger_transactions WHERE parent_tenant_id = p_parent_tenant_id;
        SELECT count(*) INTO v_wallets_count FROM public.universal_wallets WHERE parent_tenant_id = p_parent_tenant_id;
    ELSE
        IF p_target_child_id IS NULL THEN
            RAISE EXCEPTION 'Target child tenant ID is required for child_only scope.';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.tenants WHERE id = p_target_child_id AND parent_id = p_parent_tenant_id) THEN
            RAISE EXCEPTION 'Invalid child tenant ID for this parent organization.';
        END IF;

        v_target_tenant_ids := ARRAY[p_target_child_id];

        SELECT count(*) INTO v_invoice_count FROM public.global_invoices WHERE issued_by_tenant_id = p_target_child_id;
        SELECT count(*) INTO v_wallets_count FROM public.wallets WHERE tenant_id = p_target_child_id;
    END IF;

    SELECT count(*) INTO v_order_count FROM public.shop_orders WHERE tenant_id = ANY(v_target_tenant_ids);
    SELECT count(*) INTO v_cart_count FROM public.shop_carts WHERE tenant_id = ANY(v_target_tenant_ids);

    RETURN jsonb_build_object(
        'shipments', v_shipment_count,
        'stocks', v_stock_count,
        'invoices', v_invoice_count,
        'orders', v_order_count,
        'carts', v_cart_count,
        'ledgers', v_ledger_count,
        'wallets_to_reset', v_wallets_count
    );
END;
$$;


-- 3. RPC: PURGE TENANT OPERATIONAL DATA
CREATE OR REPLACE FUNCTION "public"."purge_tenant_operational_data"(
    "p_parent_tenant_id" BIGINT,
    "p_scope" TEXT DEFAULT 'all_hierarchy'::TEXT,
    "p_confirmation_slug" TEXT DEFAULT ''::TEXT,
    "p_target_child_id" BIGINT DEFAULT NULL::BIGINT
)
RETURNS JSONB
LANGUAGE "plpgsql"
SECURITY DEFINER
SET "search_path" TO 'public'
AS $$
DECLARE
    v_parent_slug TEXT;
    v_target_slug TEXT;
    v_target_id BIGINT;
    v_target_tenant_ids BIGINT[];
    v_counts JSONB;
    v_user_id UUID := auth.uid();
    v_user_email TEXT := COALESCE(public.current_user_email(), 'unknown');
BEGIN
    -- 1. Authorization Check
    IF NOT (public.is_superadmin() OR public.user_can_manage_parent_tenant(p_parent_tenant_id)) THEN
        RAISE EXCEPTION 'Unauthorized: Administrative privileges on the parent tenant required.';
    END IF;

    SELECT slug INTO v_parent_slug FROM public.tenants WHERE id = p_parent_tenant_id AND parent_id IS NULL;
    IF v_parent_slug IS NULL THEN
        RAISE EXCEPTION 'Parent tenant not found or is not a root workspace.';
    END IF;

    -- 2. Scope & Slug Matching
    IF p_scope = 'all_hierarchy' THEN
        v_target_id := p_parent_tenant_id;
        v_target_slug := v_parent_slug;

        SELECT array_agg(id) INTO v_target_tenant_ids
        FROM public.tenants
        WHERE id = p_parent_tenant_id OR parent_id = p_parent_tenant_id;
    ELSIF p_scope = 'child_only' THEN
        IF p_target_child_id IS NULL THEN
            RAISE EXCEPTION 'Target child tenant ID is required for child_only scope.';
        END IF;

        SELECT slug INTO v_target_slug
        FROM public.tenants
        WHERE id = p_target_child_id AND parent_id = p_parent_tenant_id;

        IF v_target_slug IS NULL THEN
            RAISE EXCEPTION 'Selected child tenant not found under this parent organization.';
        END IF;

        v_target_id := p_target_child_id;
        v_target_tenant_ids := ARRAY[p_target_child_id];
    ELSE
        RAISE EXCEPTION 'Invalid scope: %. Must be all_hierarchy or child_only.', p_scope;
    END IF;

    -- 3. Confirmation phrase check (case-insensitive slug match)
    IF UPPER(TRIM(p_confirmation_slug)) <> UPPER(TRIM(v_target_slug)) THEN
        RAISE EXCEPTION 'Confirmation slug mismatch. Expected %, received %.', UPPER(TRIM(v_target_slug)), UPPER(TRIM(p_confirmation_slug));
    END IF;

    -- 4. Capture preview counts for audit record
    v_counts := public.preview_tenant_data_purge(p_parent_tenant_id, p_scope, p_target_child_id);

    -- 5. Delete Dependent Return & Sales Invoices
    IF p_scope = 'all_hierarchy' THEN
        DELETE FROM public.global_return_items WHERE parent_tenant_id = p_parent_tenant_id;
        DELETE FROM public.global_returns WHERE parent_tenant_id = p_parent_tenant_id;
        DELETE FROM public.global_invoice_items WHERE parent_tenant_id = p_parent_tenant_id;
        DELETE FROM public.global_invoices WHERE parent_tenant_id = p_parent_tenant_id;
    ELSE
        DELETE FROM public.global_return_items WHERE return_id IN (
            SELECT id FROM public.global_returns WHERE parent_tenant_id = p_parent_tenant_id
        );
        DELETE FROM public.global_invoice_items WHERE invoice_id IN (
            SELECT id FROM public.global_invoices WHERE issued_by_tenant_id = p_target_child_id
        );
        DELETE FROM public.global_invoices WHERE issued_by_tenant_id = p_target_child_id;
    END IF;

    DELETE FROM public.sales_invoice_items WHERE tenant_id = ANY(v_target_tenant_ids);
    DELETE FROM public.sales_invoices WHERE tenant_id = ANY(v_target_tenant_ids);

    -- 6. Delete Orders, Carts, Settlements, Demands
    DELETE FROM public.dropship_order_settlements WHERE tenant_id = ANY(v_target_tenant_ids);
    DELETE FROM public.shop_order_items WHERE tenant_id = ANY(v_target_tenant_ids);
    DELETE FROM public.shop_order_status_history WHERE tenant_id = ANY(v_target_tenant_ids);
    DELETE FROM public.shop_orders WHERE tenant_id = ANY(v_target_tenant_ids);
    DELETE FROM public.shop_cart_items WHERE tenant_id = ANY(v_target_tenant_ids);
    DELETE FROM public.shop_carts WHERE tenant_id = ANY(v_target_tenant_ids);
    DELETE FROM public.customer_demand_bucket_items WHERE tenant_id = ANY(v_target_tenant_ids);

    -- 7. Reset Financial Ledgers & Wallets
    IF p_scope = 'all_hierarchy' THEN
        DELETE FROM public.universal_ledger_transactions WHERE parent_tenant_id = p_parent_tenant_id;
        DELETE FROM public.universal_wallet_transactions WHERE parent_tenant_id = p_parent_tenant_id;
        UPDATE public.universal_wallets SET balance = 0.00, updated_at = now() WHERE parent_tenant_id = p_parent_tenant_id;
    END IF;

    DELETE FROM public.ledger_transactions WHERE tenant_id = ANY(v_target_tenant_ids);
    DELETE FROM public.wallet_transactions WHERE tenant_id = ANY(v_target_tenant_ids);
    UPDATE public.wallets SET balance = 0.00, updated_at = now() WHERE tenant_id = ANY(v_target_tenant_ids);

    -- 8. If Full Hierarchy, Wipe Stock & Procurement Operations
    IF p_scope = 'all_hierarchy' THEN
        DELETE FROM public.stock_movements WHERE tenant_id = ANY(v_target_tenant_ids);
        DELETE FROM public.global_stock_items WHERE parent_tenant_id = p_parent_tenant_id;
        DELETE FROM public.global_stock_boxes WHERE parent_tenant_id = p_parent_tenant_id;
        DELETE FROM public.global_stocks WHERE parent_tenant_id = p_parent_tenant_id;

        DELETE FROM public.global_shipment_cost_entries WHERE parent_tenant_id = p_parent_tenant_id;
        DELETE FROM public.global_shipment_items WHERE parent_tenant_id = p_parent_tenant_id;
        DELETE FROM public.global_shipment_boxes WHERE parent_tenant_id = p_parent_tenant_id;
        DELETE FROM public.global_shipment_sections WHERE parent_tenant_id = p_parent_tenant_id;
        DELETE FROM public.global_shipments WHERE parent_tenant_id = p_parent_tenant_id;

        DELETE FROM public.costing_files WHERE tenant_id = ANY(v_target_tenant_ids);
        DELETE FROM public.product_based_costing_backlog_items WHERE tenant_id = ANY(v_target_tenant_ids);
        DELETE FROM public.product_based_costing_items WHERE product_based_costing_file_id IN (
            SELECT id FROM public.product_based_costing_files WHERE tenant_id = ANY(v_target_tenant_ids)
        );
        DELETE FROM public.product_based_costing_files WHERE tenant_id = ANY(v_target_tenant_ids);
        DELETE FROM public.shipment_investments WHERE tenant_id = p_parent_tenant_id;
    END IF;

    -- 9. Clean Trash Entries & Reset Invoice Number Counters
    DELETE FROM public.trash_entries WHERE tenant_id = ANY(v_target_tenant_ids);
    UPDATE public.sales_invoice_counters SET current_number = 0 WHERE tenant_id = ANY(v_target_tenant_ids);

    -- 10. Record Permanent Audit Log
    INSERT INTO public.tenant_data_purge_logs (
        parent_tenant_id,
        target_tenant_id,
        scope,
        executed_by,
        executor_email,
        confirmation_phrase,
        deleted_counts
    ) VALUES (
        p_parent_tenant_id,
        v_target_id,
        p_scope,
        v_user_id,
        v_user_email,
        p_confirmation_slug,
        v_counts
    );

    RETURN jsonb_build_object(
        'success', true,
        'purged_counts', v_counts,
        'purged_at', now()
    );
END;
$$;

GRANT EXECUTE ON FUNCTION "public"."preview_tenant_data_purge"(BIGINT, TEXT, BIGINT) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."purge_tenant_operational_data"(BIGINT, TEXT, TEXT, BIGINT) TO "authenticated";

COMMIT;
