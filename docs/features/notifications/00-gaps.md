# Notifications — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| NT1 | ~~doc_wrong~~ | “3 priorities” then lists 4 | Enum `low`–`urgent` | **Done (2026-10):** spec lists four priorities |
| NT2 | not_built | FCM web push via Edge | `enqueue_notification` in SQL; confirm Edge + client | Ship push or drop from spec |
| NT3 | ~~doc_wrong~~ | Tasks + notifications one spec | Two UI modules (`tasks/`, `notifications/`) | **Done (2026-10):** as-built lists both modules |
| NT4 | temp_off | Inbox + Realtime on app/shop | Flag `NOTIFICATIONS_ENABLED = false` (prod disk IO / WAL) | Re-enable after bigger compute or lighter subscribe; [fix note](../../../doc/fix/2026-10-25-prod-disk-io-budget.md) |
