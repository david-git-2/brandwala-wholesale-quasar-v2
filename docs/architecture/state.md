# State — Vue Query, Pinia, toasts

**Copy the module you edit.** Do not migrate Pinia ↔ Query unless the task says so.

## Vue Query

Used in `shop_order`, `procurement_stock`, `product_based_costing`, `thrift`, parts of `sales_invoice`.

- Keys: `web/src/modules/<module>/shared/queryKeys/` (or existing `*QueryKeys.ts`). Not a repo-root `shared/` folder.
- Edit/delete: patch or splice cache. No full list refetch.
- PATCH payloads. Optimistic update + rollback.

## Pinia

`page → store → service → repository`. Use for session/grants, filters, drawers, and lists that already use `*Store.ts`.

## Toasts (`src/utils/appFeedback.ts`)

| | Success toast | Error |
| :--- | :--- | :--- |
| Fetch | never | toast or banner |
| Mutation | always | `parseSupabaseError` — never raw SQL |
| Field validation | — | on the field |

```ts
showErrorNotification(parseSupabaseError(err, 'Failed to update record.'));
```
