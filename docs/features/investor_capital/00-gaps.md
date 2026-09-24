# Investor capital — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| IC1 | doc_wrong | PRD reinvest / portal withdraw | Locked: portal v1 read-only | **Done** |
| IC2 | sql_split | Stub `investor/` | Live `public.sql` + procurement `shipment_investments` | Split later |
| IC3 | code_wrong | Profile = identity | `InvestorBalance` on list UI | Derive on list/detail from wallet + shipments |
| IC4 | code_wrong | Cash = wallet only | `investor_transactions` duplicate journal | Retire journal; UWL source of truth |
| IC5 | doc_wrong | No `investor_capital_ledger` | Old spec | **Done** |
| IC6 | code_wrong | Portal: dashboard + shipments only | Routes `portfolio`, `allocations`, `profit`, `activity` | Two nav items; drop extra pages |
| IC7 | code_wrong | App: list + detail hub | `/capital/profiles`, `/ledger`, `/capital/shipments` | `/capital/investors` + `/:id` detail with capital + shipment table |
