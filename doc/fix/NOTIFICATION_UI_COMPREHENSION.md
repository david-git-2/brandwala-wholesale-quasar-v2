# Feature Blueprint: Notification UI Comprehension Fix

**Status:** Implemented  
**Type:** UX + copy + client state split. No new event types or tenant event log.  
**Surfaces:** App + shop bell, inbox page, browser alerts settings.  
**Related:** [`NOTIFICATIONS.md`](../notifications/NOTIFICATIONS.md)

---

## 1. User Story & Core Logic

Staff and shop users open the bell but cannot quickly answer: **what happened**, **about which order/task**, **what do I do next**. Rows looked the same, copy mixed jargon with vague next steps, and the bell shared one list with the full inbox.

**Success:** Each row reads as **[icon + kind] [title with record id] — [action line] · [time]**. Unread shows a dot. Bell preview and inbox list use separate store slices. New catalog/task notifications use locked copy; old rows still scan via `event_type` presentation map.

**Non-goals:** Telegram UI, tenant event log, per-event mute, email, backfill of old `title`/`body` rows.

---

## 2. Data Modeling & Database Schema

No table changes. Copy updates only in existing enqueue call sites:

| Event | Audience | Title | Body |
| :--- | :--- | :--- | :--- |
| `catalog.order.created` | staff | `New order {order_no}` | `{n} items to price` |
| `catalog.order.confirmed` | staff | `Order {order_no} confirmed` | `Start buying when ready` |
| `catalog.offer.countered` | staff | `{order_no} needs a final price` | `Open the order and send the last offer` |
| `catalog.offer.sent` | shop | `Offer ready for {order_no}` | `Open the order to review prices` |
| `catalog.offer.final` | shop | `Confirm {order_no}` | `Check price and quantity, then confirm` |
| `catalog.order.ready_for_shipment` | shop | `{order_no} is packing` | `We will mark it on the way when it ships` |
| `catalog.order.delivered` | shop | `Order {order_no} delivered` | `Open the order for details` |
| `catalog.order.cancelled` | shop | `Order {order_no} cancelled` | (unchanged body) |
| `task.assigned` | assignee | `Task: {title}` | `Open this task` |

Migration: `20270913150000_notification_ui_copy.sql`. Task `link_path` stays `/app/tasks` (no task detail route).

---

## 3. AuthN, AuthZ, & Permissions

N/A — same inbox RPCs and grants. Shop inbox still gated by `has_shop_notification_access`.

---

## 4. API Surface & Contracts (Per Page/Module)

N/A — `list_my_notifications_paginated`, mark read, unread count unchanged. Response shape unchanged; UI adds presentation from `event_type`.

---

## 5. UI & Responsive Design Strategy

### Row anatomy (`NotificationListItem.vue`)

- Left: category icon in avatar (primary when unread)
- Title: bold when unread
- Unread dot (8px) beside title
- Kind caption from `getNotificationPresentation(event_type).kindLabel`
- Action line: `body` or presentation `fallbackAction` (2 lines max)
- Tenant (app only): `From {operating_tenant_name}`
- Right: relative time

### Presentation map

`web/src/modules/notifications/utils/notificationPresentation.ts` — icon, kind label, fallback action per `catalog.*` and `task.assigned`; default bell + "Update".

### Empty states

- Default: "No notifications yet"
- Unread filter on, empty: "You are caught up"

### Naming

| Surface | Label |
| :--- | :--- |
| Bell / inbox route | Notifications |
| Profile menu + settings route | Browser alerts |
| Bell footer (app) | See all + Browser alerts link |

---

## 6. State Management & Routing

`notificationStore` split:

| Field | Use |
| :--- | :--- |
| `previewItems` | Bell dropdown (8 rows) |
| `inboxItems` | Full inbox page |
| `previewLoading` / `inboxLoading` | Separate skeletons |
| `previewMenuOpen` | Realtime refresh preview only when menu open |
| `unreadCount` | Shared badge + inbox filter label |

Silent refresh: no skeleton when list already loaded. Bell reloads preview on menu `@show`.

---

## 7. Style Guidelines & Accessibility

Theme tokens (`--bw-theme-*`), `data-test` on bell, list items, unread dot, filters. `v-close-popup` on bell row click and footer actions.

---

## 8. Network Handling & Loading Strategy

Pinia store + existing repository RPCs. Realtime on `notification_recipients` refreshes unread always; preview/inbox per rules above.

---

## 9. Component Specifications

| Component | Change |
| :--- | :--- |
| `NotificationBell.vue` | Preview items, menu show/hide, footer links |
| `NotificationList.vue` | Empty copy prop, skeleton avatar, `closePopupOnSelect` |
| `NotificationListItem.vue` | Full row layout |
| `NotificationInboxPage.vue` | Inbox items, `Unread only (N)` |
| `NotificationPreferencesPage.vue` | Staff-facing browser alerts copy |

---

## 10. Explicit Out of Scope

- Telegram connect UI
- Tenant notification event log page
- Per-event preference matrix
- Backfilling historical notification text
- Shop-scope browser alerts settings page

---

## 11. Testing Strategy

Manual browser checks:

- App bell: unread styling, click row → order, menu closes
- Inbox: unread filter empty state, mark all read, pagination vs bell preview
- Shop bell: shop order links
- Profile: Browser alerts → settings (not inbox)

---

## 12. Definition of Done

- [x] Presentation map + scannable list rows
- [x] Split preview/inbox store state
- [x] Catalog + task copy in schema + migration applied locally
- [x] Browser alerts naming in profile, settings, bell footer
- [x] `doc/notifications/NOTIFICATIONS.md` §9 updated
- [x] Local types regenerated after migration
