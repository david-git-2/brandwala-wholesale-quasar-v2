# Wallet — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| WA1 | sql_split | Stub `supabase/schemas/wallet/` | Live ledger in `public.sql` | Split on next wallet change |
| WA2 | doc_wrong | PRD persona “reseller withdrawal requests” | Dropship payout RPCs exist; **investor** portal has no withdraw | Split merchant payout vs investor; do not add investor withdraw |
| WA3 | doc_wrong | ACs `[ ]` | `record_ledger_transaction` is locked | Tick ledger ACs that match |
