# RPC: `generate_thrift_invoice_number`

Server-only helper / used inside create. Allocates next `INV-YYYY-MM-#####` via `thrift_invoice_counters`.

Permission: internal / create path.

Unchanged by PnL redesign.
