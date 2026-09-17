# [Feature Name] — Page-to-API Matrix

Mapping of all UI controls, interactive buttons, modal triggers, and form submissions to their corresponding Supabase RPCs, database operations, and TanStack Vue Query cache keys.

---

## 📊 Interaction & Endpoint Matrix

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation / Optimistic Update |
| :--- | :--- | :--- | :--- | :--- |
| **FeatureListPage** | Page Load / Initial Mount | `useFeatureListQuery()` | `rpc('list_feature_entities')` | Stored in `featureKeys.list(filters)` |
| **FeatureListPage** | Search Input Debounce | `useFeatureListQuery(search)` | `rpc('list_feature_entities')` | Keyed by debounced search string |
| **FeatureListPage** | Status Filter Dropdown | `useFeatureListQuery(status)` | `rpc('list_feature_entities')` | Filter state from Pinia store |
| **FeatureActionDialog** | Submit "Create Entity" | `useCreateFeatureMutation()` | `rpc('create_feature_entity')` | Optimistic append to list cache |
| **FeatureActionDialog** | Submit "Save Edits" | `useUpdateFeatureMutation()` | `rpc('update_feature_entity')` | Cache-first patch update (no refetch) |
| **FeatureListPage** | Click "Delete / Archive" | `useArchiveFeatureMutation()` | `rpc('archive_feature_entity')` | Immediate filter out from local cache |
| **FeatureDetailPage** | Tab Switch "Audit Trail" | `useFeatureAuditLogQuery()` | `select * from audit_logs` | Cached on `featureKeys.audit(id)` |
