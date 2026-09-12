# Courier COD report (report 7)

Delivered dropship COD vs remittance, short/over per courier. Uses `shop_orders` and remittance refs, not legacy wallet ledger.

**RPC:** `get_tenant_courier_cod_report`  
**Route:** `/:tenantSlug?/app/finance/reports/courier-cod`

Pass `p_courier_service_id` to load order-level rows for a courier drill-down.
