# Tenant auth — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| TA1 | doc_wrong | PRD AC says `/superadmin/*` | Routes are `/platform/*` | Edit `01-prd.md` to `/platform` |
| TA2 | doc_wrong | All ACs in `01-prd` still `[ ]` | Module is shipped | Check boxes that match code; leave only real gaps |
| TA3 | sql_split | `tenants/`, `permissions/` folders | Live SQL still mostly `public.sql` | Split when changing that domain |

No open product build besides TA3 unless a new auth story is added.
