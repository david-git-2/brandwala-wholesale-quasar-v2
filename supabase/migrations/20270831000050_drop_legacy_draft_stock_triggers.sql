-- Migration: 20270831000050_drop_legacy_draft_stock_triggers.sql
-- Description: Drop legacy triggers that mistakenly touched stock during invoice draft creation

DROP TRIGGER IF EXISTS "trg_global_invoice_items_stock_sync" ON "public"."sales_invoice_items";
DROP TRIGGER IF EXISTS "trg_global_invoices_stock_sync" ON "public"."sales_invoices";
DROP FUNCTION IF EXISTS "public"."trg_fn_global_invoice_items_stock_sync"() CASCADE;
DROP FUNCTION IF EXISTS "public"."trg_fn_global_invoices_stock_sync"() CASCADE;
