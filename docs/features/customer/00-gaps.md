# Customer — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| CU1 | sql_split | Customer domain | `public.sql` | Split on next change |
| CU2 | doc_wrong | ACs `[ ]` (create account, members, wallet tab) | Hub UI shipped | Tick matching drawers/tabs |
| CU3 | not_built | Account tab collect: split tender (cash + cheques + bKash) via pay-in | Billing-profile payment may be single-method or missing instrument lines | Same writer as [WA9–WA12](../bills_pays/00-gaps.md); allocate across open bills |
| CU4 | design | Customer = profile (`profile_type customer`) | Parallel `customer_groups` + `billing_profiles` | [BP3](../bills_pays/00-gaps.md); [02 Profile](../bills_pays/02-data-model.md#profile) |
