# Customer — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| CU1 | sql_split | Customer domain | `public.sql` | Split on next change |
| CU2 | doc_wrong | ACs `[ ]` (create account, members, wallet tab) | Hub UI shipped | Tick matching drawers/tabs |
| CU3 | not_built | Account tab collect: split tender (cash + cheques + bKash) via wallet receipt | Billing-profile payment may be single-method or missing instrument lines | Same receipt writer as [wallet WA9–WA12](../wallet/00-gaps.md); allocate across open invoices |
