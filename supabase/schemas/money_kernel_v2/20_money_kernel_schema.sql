-- Money spine v2 — kernel schema (parallel to legacy public money tables).
-- Spec: docs/features/money_bill_bridge/spec.md

CREATE SCHEMA IF NOT EXISTS money_kernel;
ALTER SCHEMA money_kernel OWNER TO postgres;

REVOKE ALL ON SCHEMA money_kernel FROM PUBLIC;
GRANT USAGE ON SCHEMA money_kernel TO postgres, service_role;
GRANT USAGE ON SCHEMA money_kernel TO authenticated;
