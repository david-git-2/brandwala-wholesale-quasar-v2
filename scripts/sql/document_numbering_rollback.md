# Document numbering rollback

1. Revert application migration `20261105164000_document_numbering.sql` only if you must roll back code in the same release (restore prior function bodies from git).
2. Do **not** delete rows from `document_number_counters` — you would lose sequence positions.
3. Legacy tables kept for read/rollback reference:
   - `sales_invoice_counters` (no longer written by `generate_sales_invoice_number`)
   - `tenant_scoped_counters` scope `shipment` (superseded by `doc_type = shipment`; `next_tenant_scoped_counter('shipment')` delegates to document numbering)

Re-point wrappers to old implementations from git history if a hotfix is required before the next deploy.
