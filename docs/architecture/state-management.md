# Architecture: State Management & Data Fetching

TradeFlow BD uses a dual-layer state management model: **TanStack Vue Query (v5)** for server state and **Pinia (v3)** for client UI state.

---

## 🔄 Server State: TanStack Vue Query

### Key Principles
1. **Cache-First Mutations**: On update or delete, do not refetch the entire table. Manually update the Vue Query cache entry or splice out the deleted item.
2. **Partial Payloads (PATCH Style)**: Only transmit modified fields when submitting an edit form.
3. **Query Key Factories**: Group query keys by module:
   ```typescript
   export const invoiceKeys = {
     all: ['sales_invoices'] as const,
     lists: () => [...invoiceKeys.all, 'list'] as const,
     list: (filters: InvoiceFilterState) => [...invoiceKeys.lists(), filters] as const,
     details: () => [...invoiceKeys.all, 'detail'] as const,
     detail: (id: string) => [...invoiceKeys.details(), id] as const,
   };
   ```
4. **Optimistic Updates**: Immediately apply changes to local UI cache before the network round-trip finishes, rolling back if the request fails.

---

## 🗃️ Client State: Pinia Stores

Pinia stores are reserved strictly for:
- Ephemeral UI filters (e.g. date range pickers, multi-select rows)
- Active tenant/user session state
- Drawer/sidebar visibility and user preferences

Do not duplicate remote database tables into persistent Pinia state; rely on TanStack Vue Query caching instead.
