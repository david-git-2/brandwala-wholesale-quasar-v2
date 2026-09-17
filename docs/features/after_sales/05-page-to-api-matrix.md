# After-Sales & Returns — Page-to-API Matrix

Mapping of all Returns Hub views, dialogs, inspection desks, and case outcome executions to their corresponding Supabase RPCs, database operations, and TanStack Vue Query cache keys.

---

## 📊 Interaction & Endpoint Matrix

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation / Optimistic Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **`ReturnsHubPage`** | Mount / Tab Filter / Search | `useAfterSalesCasesQuery` | `RPC: list_after_sales_cases_paginated` | Cached on `afterSalesQueryKeys.cases` (`staleTime: 30s`) |
| **`CreateRmaCaseDialog`** | Submit "Open Case" | `useCreateRmaCaseMutation` | `RPC: create_after_sales_case` | Invalidates active case list |
| **`DropshipIntakeLogDialog`** | Log External Complaint | `useLogDropshipIntakeMutation` | `RPC: create_after_sales_case` (with intake fields) | Appends case, invalidates case list |
| **`AfterSalesCaseDetailPage`** | Approve Pending Case | `useApproveRmaCaseMutation` | `RPC: approve_after_sales_case` | Updates case status to `approved` |
| **`AfterSalesCaseDetailPage`** | Execute Line Outcome | `useExecuteCaseLineMutation` | `RPC: execute_after_sales_case_line` | Triggers credit/replace RPC; invalidates case |
| **`AfterSalesPoliciesPage`** | Update Policy Programs | `useUpdatePoliciesMutation` | `RPC: upsert_after_sales_policies` | Invalidates `afterSalesQueryKeys.policies` |
