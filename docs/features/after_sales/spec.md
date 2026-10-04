# After-sales & returns — spec

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/after_sales/spec.md` + [00-gaps](00-gaps.md) |
| UI | `web/src/modules/after_sales/` |
| SQL | `process_wholesale_invoice_return`, `finalize_dropship_return` in schemas |
| State | Copy module pattern |
| Access | `app`; `effectiveGrants` |

## Where to look

| Need | Path |
| :--- | :--- |
| RPCs | Grep return RPC names in `public.sql` + shop_order |
| Pages | `web/src/modules/after_sales/pages/` |
| Policies | Grep RMA / return policy tables |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` |
| In | RMA cases, return policy, wholesale + dropship return execution |
| Out | Original invoice create; warehouse bins; delivery-paper close; inbound vendor credit ([procurement US-7](../procurement_stock/spec.md)) |

## Personas

| Role | Actions |
| :--- | :--- |
| Support | Log dropship complaints, open cases, receive goods |
| Warehouse inspector | Condition, outcome routing |
| Sales manager | Approve high-value / fee waivers |
| Parent admin | Policy windows, restocking fees |

## Stories

### US-1: Returns hub
- Unified `/app/after-sales` for wholesale + dropship.
  - [ ] Tabs: All, Awaiting receipt, Inspecting, Completed.
  - [ ] Links to `sales_invoices` and `shop_orders`.

### US-2: Policy programs
- Programs: `return_credit`, `doa`, `replacement`, `warranty`.
  - [ ] Policy snapshot on case create.
  - [ ] DOA/replacement waive restocking.

### US-3: Inspection & outcomes
- Credit, replace, repair, reject.
  - [ ] Sellable/held via `return_inbound` movements.
  - [ ] Credit reduces invoice due first; overpay → store credit.
