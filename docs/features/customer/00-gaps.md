# Customer — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| CU1 | sql_split | Customer domain | `public.sql` | Split on next change |
| CU5 | not_built | Wallet Ledger tab, collect, manual wallet actions | Removed with bills_pays UI teardown ([BP5](../bills_pays/00-gaps.md)) | Restore on cashbook desk |
| CU2 | doc_wrong | ACs `[ ]` (create account, members, wallet tab) | Hub UI shipped; wallet tab out until BP5 | Tick non-wallet drawers/tabs only |
| CU3 | not_built | Account tab collect: split tender (cash + cheques + bKash) via pay-in | Billing-profile payment may be single-method or missing instrument lines | Same writer as [WA9–WA12](../bills_pays/00-gaps.md); allocate across open bills |
| CU4 | design | Customer = profile (`profile_type customer`) | Parallel `customer_groups` + `billing_profiles` | [BP3](../bills_pays/00-gaps.md); [02 Profile](../bills_pays/02-data-model.md#profile) |
