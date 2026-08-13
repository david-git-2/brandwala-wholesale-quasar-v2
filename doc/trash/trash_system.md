# Generic Trash and Soft Delete System

## 1. Overview
The Trash module provides a centralized, reusable architecture for handling deleted records across the Brandwala v2 system. Instead of permanently deleting records immediately (hard delete), records are marked as deleted (soft delete). This allows users to view deleted items in a unified Trash UI, restore them if needed, and rely on an automated system to permanently prune old data.

## 2. Core Schema Pattern (SoftDeletable)
Any transactional or user-managed entity (e.g., Products, Shipments, Vendors, Invoices) implements the `SoftDeletable` interface by including the following columns:

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `deleted_at` | TIMESTAMPTZ | No | Timestamp when the record was soft-deleted. If `NULL`, the record is active. |
| `deleted_by` | UUID | No | References `auth.users(id)`. The user who deleted the record. |

*Note: System reference data (like global markets or currencies) are immutable and do not implement this pattern.*

## 3. Database Rules & RLS
To prevent deleted records from showing up in active workflows:
1. **Row Level Security (RLS)**: Policies on standard reads MUST include a condition like `deleted_at IS NULL` for standard roles.
2. **Views**: If views are used, they should automatically append `WHERE deleted_at IS NULL`.
3. **Trash Access**: A specific admin role or bypass policy allows reading records where `deleted_at IS NOT NULL`.

## 4. API & Application Logic

### 4.1 Delete (Soft Delete)
When a client requests to delete an entity (e.g., `DELETE /api/products/123`), the API or RPC executes an `UPDATE` instead of a `DELETE`:
```sql
UPDATE products 
SET deleted_at = NOW(), deleted_by = auth.uid() 
WHERE id = 123;
```

### 4.2 Restore
To restore an entity (e.g., `POST /api/products/123/restore`), the API executes:
```sql
UPDATE products 
SET deleted_at = NULL, deleted_by = NULL 
WHERE id = 123;
```

## 5. Unified Trash UI
The application will feature a single **Unified Trash Page**. 
- The UI will fetch data from a unified endpoint or specific RPCs (e.g., `get_trash_items()`) that UNIONs deleted records from various modules.
- Users can easily filter by module (e.g., "Show deleted Shipments", "Show deleted Products") from one central interface rather than navigating to each module's own trash bin.

## 6. Automated Pruning (Hard Deletion)
To prevent the database from infinitely growing with junk data, a scheduled `pg_cron` job (or Supabase Edge Function cron) runs daily to permanently delete records that have been in the trash for more than **30 days**.

**Example Pruning Job:**
```sql
-- Runs daily at midnight
SELECT cron.schedule('prune_trash_daily', '0 0 * * *', $$
    DELETE FROM products WHERE deleted_at < NOW() - INTERVAL '30 days';
    DELETE FROM shipments WHERE deleted_at < NOW() - INTERVAL '30 days';
    -- (repeated for all SoftDeletable tables)
$$);
```
