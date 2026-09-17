# Tasks & Notifications — API Contract & RPC Signatures

> **RPC Functions Target**: In-App Inbox, Unread Counter, Task Management & FCM Preferences  
> **Security Level**: `SECURITY DEFINER`

---

## 1. User Inbox & Unread Count RPCs

### 1.1 Unread Count RPC: `get_unread_notifications_count`
```sql
create or replace function public.get_unread_notifications_count()
returns bigint
language sql security definer;
```

### 1.2 Mark as Read RPC: `mark_notification_as_read`
```sql
create or replace function public.mark_notification_as_read(
  p_notification_id uuid
)
returns void
language plpgsql security definer;
```

### 1.3 Mark All as Read RPC: `mark_all_notifications_as_read`
```sql
create or replace function public.mark_all_notifications_as_read()
returns void
language plpgsql security definer;
```

---

## 2. Task Management Mutations

### 2.1 Create Task Mutation: `create_task`
```sql
create or replace function public.create_task(
  p_parent_tenant_id uuid,
  p_title text,
  p_priority public.task_priority,
  p_assigned_to_user_id uuid default null,
  p_due_date date default null,
  p_description text default null,
  p_entity_type text default null,
  p_entity_id uuid default null
)
returns jsonb
language plpgsql security definer;
```

### 2.2 Complete Task Mutation: `complete_task`
```sql
create or replace function public.complete_task(
  p_task_id uuid
)
returns jsonb
language plpgsql security definer;
```
