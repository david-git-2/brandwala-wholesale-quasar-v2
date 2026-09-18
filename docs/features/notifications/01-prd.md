# Tasks & Notifications — Product Requirements Document (PRD)

> **Module**: Operational Task Delegation, Realtime In-App Inbox & Multi-Channel Push Notifications  
> **Status**: Approved & Active  
> **Target Release**: v2.4.0  
> **Target Audience**: Tenant Staff, Operations Coordinators, Storefront Buyers, Platform Administrators

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/notifications/` |
| UI | `web/src/modules/notifications/`, `tasks/` |
| SQL | **Split** `supabase/schemas/notifications/` (`03_rls.sql`, `04_rpcs.sql`) |
| Access | `app` (and shop where inbox exists) |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` tasks + inbox; shop inbox if enabled |
| In | `enqueue_notification`, in-app inbox, tasks |
| Out | Building ERP pages; Telegram unless already shipped |

See [scopes](../../architecture/scopes.md).

---

## 1. Executive Summary

The **Tasks & Notifications** module coordinates operational work delegation across team members and provides an event-driven notification dispatch pipeline supporting in-app realtime inboxes, browser web push (Firebase Cloud Messaging - FCM), and external messaging bots.

Operational tasks (`tasks`) allow team leads to assign and track checklist items tied to specific orders, customers, or shipments. Notifications (`notifications`) deliver instant, role-scoped alerts to designated user recipients whenever business events occur.

---

## 2. User Personas & Permissions

| Role | Access Level | Permitted Actions |
| :--- | :--- | :--- |
| **Operations Team Lead** | Full Access | Create and assign tasks, set due dates and priorities, broadcast system-wide notifications. |
| **Operational Staff** | Operational | Complete assigned tasks, view in-app notification inbox, mark alerts as read, opt-in to browser push notifications. |
| **Storefront Customer** | Shop Scope | Receive order status updates, price quotes, and shipment tracking notifications. |

---

## 3. User Stories & Acceptance Criteria

### US-1: Multi-Channel Notification Pipeline
- **As a** Staff Operator  
- **I want to** receive immediate alerts for relevant domain events via in-app notification bell and optional browser push  
- **So that** urgent exceptions (order placement, stock pick needed, return opened) are addressed rapidly.

#### Acceptance Criteria
- [ ] In-app notifications deliver in real-time via Supabase Realtime subscriptions.
- [ ] FCM Web Push dispatches notifications to opted-in Chrome/Android browsers via Edge Functions.
- [ ] Scope enforces parent-tenant boundaries (`parent_tenant_id`).

### US-2: Operational Tasks & Assignments
- **As an** Operations Coordinator  
- **I want to** assign tasks to specific staff members with due dates and link them to domain records (shipments, orders, invoices)  
- **So that** operational responsibilities are clear and tracked to completion.

#### Acceptance Criteria
- [ ] Tasks support 3 priorities: `low`, `medium`, `high`, `urgent`.
- [ ] Completing a task logs the completion timestamp and user reference.

---

## 4. UI Layout & Wireframe

### Operational Tasks & In-App Notification Drawer

```text
+----------------------------------------------------------------------------------------------------+
| Breadcrumbs: App > Operations > Task Manager                                                       |
+----------------------------------------------------------------------------------------------------+
| [ Filter: Assigned to Me v ] [ Priority: All v ] [ Status: Pending v ]            [ + Create Task ]|
+----------------------------------------------------------------------------------------------------+
| PRIORITY | TASK TITLE                       | ASSIGNED TO   | LINKED ENTITY    | DUE DATE  | STATUS|
|----------+----------------------------------+---------------+------------------+-----------+-------|
| URGENT   | Inspect damaged box in SHP-001   | Nusrat Jahan  | SHP-202609-001   | Today     | [Done]|
| HIGH     | Call Metro Mart for payment rec  | Tanvir Khan   | INV-WS-001       | Tomorrow  | [Done]|
| MEDIUM   | Pick stock for dropship order    | Rafiq Ahmed   | DS-ORD-10021     | Sep 19    | [Done]|
+----------------------------------------------------------------------------------------------------+
```
