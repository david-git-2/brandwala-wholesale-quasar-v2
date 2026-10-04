# Tenant auth — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| TA1 | ~~doc_wrong~~ | AC said `/superadmin/*` | Routes are `/platform/*` | **Done:** [spec](spec.md) US-2 |
| TA2 | doc_wrong | ACs still `[ ]` in spec | Module shipped | Tick boxes that match code |
| TA3 | sql_split | `tenants/`, `permissions/` folders | Live SQL still mostly `public.sql` | Split when changing that domain |

No open product build besides TA3 unless a new auth story is added.
