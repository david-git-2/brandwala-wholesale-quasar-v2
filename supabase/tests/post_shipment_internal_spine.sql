-- Inbound internal spine helpers (no post_stock_movement changes).

BEGIN;

SELECT plan(6);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = '_stock_spine_upsert_receive_lot'
  ),
  '_stock_spine_upsert_receive_lot exists'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = '_stock_spine_finalize_inbound_movement'
  ),
  '_stock_spine_finalize_inbound_movement exists'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = '_stock_spine_receive_shipment_outcomes'
  ),
  '_stock_spine_receive_shipment_outcomes exists'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'post_shipment_outcome_stock'
      AND p.prosrc LIKE '%_stock_spine_receive_shipment_outcomes%'
  ),
  'post_shipment_outcome_stock delegates to internal orchestrator'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'post_shipment_outcome_stock'
      AND p.prosrc LIKE '%post_stock_movement%'
  ),
  'post_shipment_outcome_stock does not call post_stock_movement'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = '_stock_spine_finalize_inbound_movement'
      AND p.prosrc LIKE '%is_posted = true%'
      AND p.prosrc NOT LIKE '%post_stock_movement%'
  ),
  'inbound finalize marks movement posted without post_stock_movement'
);

SELECT finish();
ROLLBACK;
