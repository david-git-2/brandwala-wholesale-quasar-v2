# Tasks & notifications — spec

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/notifications/spec.md` + [00-gaps](00-gaps.md) |
| UI | `web/src/modules/notifications/`, `tasks/` |
| SQL | **Split** `supabase/schemas/notifications/` (`03_rls.sql`, `04_rpcs.sql`) |
| State | Mix — copy neighbors |
| Access | `app` (shop inbox if enabled) |

## Where to look

| Need | Path |
| :--- | :--- |
| Tables, RLS, RPCs | `supabase/schemas/notifications/` |
| Enqueue / inbox | Grep `enqueue_notification` in schemas and module |
| Tasks UI | `web/src/modules/tasks/` |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` tasks + inbox; shop inbox if enabled |
| In | `enqueue_notification`, in-app inbox, tasks |
| Out | Building ERP pages; Telegram unless already shipped |

See [scopes](../../architecture/scopes.md).

## Personas

| Role | Actions |
| :--- | :--- |
| Team lead | Create/assign tasks, broadcast notifications |
| Staff | Complete tasks, inbox, browser push opt-in |
| Shop customer | Order/status notifications |

## Stories

### US-1: Multi-channel notification pipeline
- In-app bell + optional FCM web push.
  - [ ] Realtime via Supabase subscriptions.
  - [ ] FCM via Edge Functions for opted-in browsers.
  - [ ] Parent-tenant scope (`parent_tenant_id`).

### US-2: Operational tasks
- Assign tasks with due dates linked to domain records.
  - [x] Priorities: `low`, `medium`, `high`, `urgent` (four levels).
  - [ ] Completion logs user + timestamp.
