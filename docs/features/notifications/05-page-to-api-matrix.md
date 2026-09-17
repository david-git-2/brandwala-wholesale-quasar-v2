# Tasks & Notifications — Page-to-API Matrix

Mapping of all notification bells, inboxes, task management desks, and push permission toggles to their corresponding Supabase RPCs, database operations, and Pinia stores.

---

## 📊 Interaction & Endpoint Matrix

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation / Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **`NotificationBell`** | Header Mount | `notificationStore.fetchUnreadCount` | `RPC: get_unread_notifications_count` | Realtime subscription updates |
| **`NotificationDrawer`** | Drawer Open | `notificationStore.fetchNotifications` | `Table: notification_recipients` join | Updates `notificationStore.items` |
| **`NotificationDrawer`** | Click Notification Row | `notificationStore.markAsRead` | `RPC: mark_notification_as_read` | Optimistic `unreadCount` decrement |
| **`NotificationDrawer`** | Click "Mark All Read" | `notificationStore.markAllAsRead` | `RPC: mark_all_notifications_as_read` | Clears unread counter |
| **`TasksPage`** | Mount / Filter by Status | `useTasksQuery` | `Table: tasks` | Cached on `['tasks', 'list', params]` |
| **`TaskCreateDialog`** | Submit "Create Task" | `useCreateTaskMutation` | `RPC: create_task` | Appends task, invalidates task list |
| **`TasksPage`** | Click "Complete Task" | `useCompleteTaskMutation` | `RPC: complete_task` | Updates status to `completed` |
