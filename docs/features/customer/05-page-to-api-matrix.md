# Customer Hub — Page-to-API Matrix

Mapping of all UI views, drawers, tabs, and modals to their corresponding Supabase RPCs, database operations, and TanStack Vue Query cache keys.

---

## 📊 Interaction & Endpoint Matrix

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation / Optimistic Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **`CustomerHubPage`** | Mount / Search / Paginate | `useCustomerListQuery` | `RPC: list_customer_accounts_paginated` | Cached on `customerQueryKeys.list` (`staleTime: 60s`) |
| **`CustomerCreateDialog`** | Submit "Create Customer" | `useCreateCustomerMutation` | `RPC: create_customer_account` | Appends new group to list; invalidates directory |
| **`CustomerHubPage`** | Click Row "Delete" | `useDeleteCustomerMutation` | `Table: customer_groups` (sets `deleted_at`) | Optimistic removal from active table |
| **`CustomerDetailDrawer`** | General Tab "Save Edits" | `useUpdateCustomerMutation` | `Table: customer_groups` & `billing_profiles` | Patch update; invalidates customer details |
| **`CustomerDetailDrawer`** | Members Tab "Add User" | `useAddMemberMutation` | `Table: customer_group_members` | Invalidates `customerQueryKeys.members(groupId)` |
| **`CustomerDetailDrawer`** | Account Tab "Inspect Dues" | `useCustomerAccountQuery` | `RPC: get_customer_account_summary_for_staff` | Cached on `customerQueryKeys.account` |
| **`CustomerDetailDrawer`** | Wallet Tab "Transaction Log"| `useWalletQuery` | `RPC: list_wallet_ledger_for_staff` | Cached on `walletQueryKeys.ledgerList` |
