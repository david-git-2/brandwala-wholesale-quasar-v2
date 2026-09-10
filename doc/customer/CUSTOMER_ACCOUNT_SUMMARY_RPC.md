# Customer account summary RPC

Single-customer financial snapshot for the **Account** tab in [`CustomerDetailDrawer.vue`](../../web/src/modules/customer/components/CustomerDetailDrawer.vue).

Related: [`CUSTOMER.md`](./CUSTOMER.md) · [`CUSTOMER_DUES.md`](../reporting_treasury/CUSTOMER_DUES.md) (all-customer report; not required for this RPC)

---

## Two-pot model

| Pot | Meaning | Source |
| :--- | :--- | :--- |
| **They owe us** | Invoice AR | `sales_invoices.due_amount` (issued) |
| **We owe them** | Store credit / merchant wallet | `wallet_accounts.available_balance` |

Do **not** net wallet into dues in the RPC. Staff apply wallet to invoices via `collect_wholesale_invoice_payment`.

---

## RPC: `get_customer_account_summary_for_staff`

```sql
get_customer_account_summary_for_staff(
  p_tenant_id bigint,
  p_customer_group_id bigint
) returns jsonb
```

**Auth:** `is_tenant_staff(p_tenant_id)` OR `membership_has_module_action(books_tenant_id, 'customer', 'view')`.

**Books tenant:** `resolve_parent_tenant_id(p_tenant_id)`.

**Customer group:** `customer_groups.id = p_customer_group_id` and `parent_tenant_id = books` and `deleted_at is null`.

**Billing profile:** the one row with `billing_profiles.customer_group_id = p_customer_group_id`. Profile `parent_tenant_id` = books. Hub account tab is for grouped customers only.

### Success JSON

```json
{
  "success": true,
  "books_tenant_id": 15,
  "billing_profile_id": 31,
  "still_due": 0,
  "total_billed": 27514,
  "collected_cash": 0,
  "wallet_applied": 0,
  "settlement": 0,
  "store_credit_balance": 15816,
  "unallocated_payments": 0,
  "open_invoices": [],
  "recent_payments": [],
  "recent_ledger": [],
  "shop_access": []
}
```

| Field | Rule |
| :--- | :--- |
| `still_due` | `sum(due_amount)` issued invoices for group billing profiles |
| `total_billed` | `sum(total_amount)` issued |
| `collected_cash` | `invoice_payments` → `global_payments` where `method <> 'wallet_credit'` |
| `wallet_applied` | same join where `method = 'wallet_credit'` |
| `settlement` | `sum(settlement_discount_amount)` |
| `store_credit_balance` | primary billing profile wallet on parent books |
| `unallocated_payments` | `sum(global_payments.unallocated_amount)` |
| `open_invoices` | issued, `due_amount > 0`, limit 50 |
| `recent_payments` | `global_payments` limit 30 |
| `recent_ledger` | `universal_wallet_ledger` for customer entity, limit 30 |
| `shop_access` | `shop_customer_group_access` + shop/tenant names, limit 20 |

### Errors

```json
{ "success": false, "error": "access denied" }
{ "success": false, "error": "customer group not found" }
```

When no billing profile: `success: true`, `billing_profile_id: null`, zeros and empty arrays (shop_access still populated).

---

## Write actions (UI only — existing RPCs)

| Action | RPC |
| :--- | :--- |
| Collect on invoice | `collect_wholesale_invoice_payment` |
| Deposit / credit / withdraw | `record_wallet_manual_transaction_for_staff` |

---

## Billing profile resolution

`resolve_billing_profile_for_customer_group` loads the single `billing_profiles` row for that `customer_group_id`. Books scope is `customer_groups.parent_tenant_id`. No family-wide hunt.
