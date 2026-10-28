# Bills desk — routes, APIs, stores

**UI:** `web/src/modules/bills_pays/` · **Data:** [`billsRepository.ts`](../../../web/src/modules/bills_pays/repositories/billsRepository.ts) · **Routes:** `/:slug/app/bills`

Map: [README.md](README.md) · Kernel RPCs: [kernel-schema.md](kernel-schema.md)

## Routes

| Page | Route name | Path |
| :--- | :--- | :--- |
| BillsPage | `app-bills-page` | `/app/bills` |
| BillComposePage | `app-bill-compose-page` | `/app/bills/create` |
| BillBrandsPage | `app-bill-brands-page` | `/app/bills/brands` |
| BillDetailPage | `app-bill-detail-page` | `/app/bills/:billId` |
| BillPreviewPage | `app-bill-preview-page` | `/app/bills/:billId/preview` |

Legacy `/app/sales/invoices/*` redirects to `/app/bills/*`.

## Client stores (no repeat fetch)

| Store | Use |
| :--- | :--- |
| `customerProfileStore` / `useCustomerProfiles` | Compose party pickers |
| `tenantStore` + `useBooksCurrencyCode` | Books currency |
| `globalReferenceStore` / `useGlobalCurrenciesQuery` | Settlement currency lists |
| Vue Query + `billsQueryKeys` | Bill list, detail bundle, items |

## Kernel / wrapper RPCs (call via `billsRepository` only)

| RPC | Desk |
| :--- | :--- |
| `upsert_draft_bill` | Create draft — adapters: `shipment_cost`, `dropship_courier`, `shop_order`, default `compose` |
| `update_draft_bill` | Update draft (kernel `_kernel_update_compose_draft`) |
| `issue_bill` / `issue_wholesale_bill` / `issue_retail_bill` | Issue — wholesale stock → `_kernel_issue_wholesale_stock`; header-only → `issue_bill` |
| `void_bill` | Void |
| `get_bill_detail_bundle` | Detail: bill, history, balances, adjustments, `stock_items`, `bill_lines` |
| `get_bill_net_balances` | Balances (inside bundle) |
| `list_global_invoice_items` | Stock lines |
| `list_bills_desk_page` | Bills list (keyset; slim rows) |
| PostgREST `bills` | Profile-scoped open-bill pickers (`listBills` legacy) |
| PostgREST `invoice_brands` | Bill brands CRUD |

### Bills list (`BillsPage`)

- **RPC:** `list_bills_desk_page(p_parent_tenant_id, p_issued_by_tenant_id?, p_ar_side?, filters…, p_page_size?, p_cursor?)`
- **Response:** `{ data: BillListRow[], meta: { has_more, next_cursor } }` — no total count.
- **UI:** `useBillsListInfiniteQuery` → Load more; fields match [`types/billList.ts`](../../../web/src/modules/bills_pays/types/billList.ts).

Frozen spine: do not alter `05_money_spine.sql`; new desk wrappers live in `06_bills_desk_wrappers.sql`.

## Issue routing (compose)

```text
retail → issue_retail_bill
wholesale + stock lines → issue_wholesale_bill
else → issue_bill
```
