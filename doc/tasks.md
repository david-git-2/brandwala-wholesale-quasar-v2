# Task Management Module

The `tasks` module provides a hierarchical work item and collaboration system, enabling teams to manage projects, modules, submodules, tasks, discussions, bugs, features, and notes.

---

## 1. Core Structure

The module is built around a nested item model and associated collaboration tables:

*   **`items`**: The central table representing all work items.
    *   **Types**: `project`, `module`, `submodule`, `task`, `note`, `discussion`, `bug`, `feature`.
    *   **Statuses**: `todo`, `in_progress`, `review`, `done`, `blocked`, `archived`.
    *   **Priorities**: `low`, `medium`, `high`, `urgent`.
    *   **Accessibility**: `public`, `private`, `restricted`.
    *   **Hierarchy**: Supports nesting via a self-referencing `parent_id` foreign key.
*   **`item_assignees`**: Maps internal members assigned to specific items.
*   **`tags` & `item_tags`**: Organizes items using colors and custom tags scoped per tenant.
*   **`comments`**: Threaded discussion logs linked to items (supports replies via `parent_comment_id`).
*   **`item_permissions`**: Explicit item-level access control roles (`owner`, `manager`, `editor`, `viewer`, `commenter`).
*   **`activity_logs`**: Auditable log of state changes (e.g. status updates, transitions, assignments).

---

## 2. Access Control & RLS

Permissions are handled recursively through the `get_effective_item_role(p_item_id, p_user_email)` helper function.

### Role Mapping Flow
1.  **Superadmin**: Granted `'owner'` access globally across all items.
2.  **Creator**: The user who created the item (`created_by_email`) is automatically the `'owner'`.
3.  **Explicit Permission**: Checked in the `item_permissions` table.
4.  **Recursive Inheritance**: If no explicit permission is found, it recursively checks the parent item's permissions (`parent_id`).
5.  **Tenant Membership Fallback**: If no specific item permissions exist, access falls back to the user's tenant-wide membership role:
    *   `admin` $\rightarrow$ `'owner'`
    *   `staff` $\rightarrow$ `'editor'`
    *   `viewer` $\rightarrow$ `'viewer'`

---

## 3. Global Cross-Tenant Search

The module includes a powerful global search index allowing users to find tasks across all tenants they belong to.

### Function: `global_search_tasks(p_query)`
*   **Scope**: Searches all items where the current authenticated user has an active membership/access role.
*   **Indices Searched**:
    *   Item Title (`items.title`)
    *   Item Content (`items.content`)
    *   Tag Name (`tags.name` via associated tags)
    *   Comment Body (`comments.body` via associated comments)
*   **Sorting**: Matches are returned ordered by `updated_at DESC` (most recently updated items first), capped at a limit of 50 records.

---

## 4. Key RPC APIs

*   `list_items_paginated()`: Retrieves items for the catalog with advanced filters (status, type, priority, assignee, parent items).
*   `get_item_details()`: Retrieves a unified JSON payload containing the item, assignees, tags, comments, permissions, and activity logs.
*   `global_search_tasks()`: Executes the cross-tenant keyword search.
