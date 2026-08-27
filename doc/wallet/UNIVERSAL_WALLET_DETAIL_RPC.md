# Universal Wallet Page RPCs (`UniversalWalletPage.vue`)

New server functions for the **wallet detail** screen: header, balances, transaction history, manual Pay/Deposit/Credit/Withdraw, and ledger reversal (“edit”).

**Consumer:** [`UniversalWalletPage.vue`](../../../web/src/modules/wallet/pages/UniversalWalletPage.vue), [`WalletActionModal.vue`](../../../web/src/modules/wallet/components/WalletActionModal.vue)  
**Do not use for list page:** [`LIST_WALLET_ENTITIES_RPC.md`](./LIST_WALLET_ENTITIES_RPC.md)  
**Books model:** [`WALLET.md`](./WALLET.md) §1.1, migration [`WALLET_PARENT_BOOKS_IMPLEMENTATION.md`](./WALLET_PARENT_BOOKS_IMPLEMENTATION.md)  
**Status:** Spec only — **not implemented**

**Replace (do not extend) for this page:**

| Legacy | Replacement |
| :--- | :--- |
| Direct `billing_profiles` / `vendors` / … name fetch | `get_wallet_detail_for_staff` |
| `get_wallet_account_balances` | part of `get_wallet_detail_for_staff` |
| `walletRepository.fetchLedgerEntries` (table select) | `list_wallet_ledger_for_staff` |
| `record_ledger_transaction` from UI | `record_wallet_manual_transaction_for_staff` |
| `get_wallet_entity_statement` | not used on this page (report/export only) |

---

## Shared rules

```text
v_books_id      := resolve_parent_tenant_id(p_tenant_id)
v_operating_id  := p_tenant_id   -- active app tenant (child or standalone)
```

- Wallet lookups: `parent_tenant_id = v_books_id` (after P0 migration; interim `tenant_id = v_books_id`).
- Auth: `membership_has_module_action(v_books_id, 'universal_wallet', 'view')` for reads; `'edit'` or `'configure'` for writes (pick one action key in implementation — default **`edit`** for manual tx).
- Ledger remains **append-only**. There is no UPDATE on `universal_wallet_ledger`. “Edit” = **reversal** RPC.

---

## 1. `get_wallet_detail_for_staff`

Single load for page header + balance card (replaces `fetchEntityName` + `useWalletAccounts` on mount).

### Signature

```sql
get_wallet_detail_for_staff(
  p_tenant_id     bigint,
  p_entity_type   text,
  p_entity_id     bigint,
  p_currency_code text DEFAULT 'BDT'
)
RETURNS jsonb
```

### Params

| Param | Notes |
| :--- | :--- |
| `p_tenant_id` | `authStore.selectedTenant.id` |
| `p_entity_type` | `tenant`, `customer`, `vendor`, `courier`, `cargo_company`, `investor` |
| `p_entity_id` | Wallet key (for `tenant`: **books parent id** after migration; for `courier`: `wallet_entity_id`) |
| `p_currency_code` | Default BDT |

### Success JSON

```json
{
  "success": true,
  "books_tenant_id": 10,
  "operating_tenant_id": 11,
  "entity": {
    "entity_type": "courier",
    "entity_id": 1,
    "name": "Steadfast Courier",
    "code": "STEADFAST",
    "caption": "Last-mile COD",
    "source_uuid": "ddbc70d2-af8c-4f4b-a504-96f186e659ab"
  },
  "account": {
    "currency_code": "BDT",
    "available_balance": 60.0000,
    "pending_balance": 0.0000,
    "locked_balance": 0.0000,
    "total_balance": 60.0000
  },
  "permissions": {
    "can_record_manual": true,
    "can_reverse": true
  }
}
```

### Entity resolution (server-side)

Same display rules as [`LIST_WALLET_ENTITIES_RPC.md`](./LIST_WALLET_ENTITIES_RPC.md) per `entity_type` (billing profile name, vendor code, courier by `wallet_entity_id`, etc.). Company wallet (`tenant`): name from `tenants` where `id = p_entity_id` (books id).

### Errors

```json
{ "success": false, "error": "access denied" }
{ "success": false, "error": "entity not found" }
```

Return zeros for `account` if no `wallet_accounts` row yet.

---

## 2. `list_wallet_ledger_for_staff`

Paginated transaction history for [`UniversalWalletLedgerTable.vue`](../../../web/src/modules/wallet/components/UniversalWalletLedgerTable.vue).

### Signature

```sql
list_wallet_ledger_for_staff(
  p_tenant_id       bigint,
  p_entity_type     text,
  p_entity_id       bigint,
  p_search          text    DEFAULT NULL,
  p_operating_tenant_id bigint DEFAULT NULL,
  p_limit           integer DEFAULT 50,
  p_offset          integer DEFAULT 0
)
RETURNS TABLE (
  id                  uuid,
  parent_tenant_id    bigint,
  operating_tenant_id bigint,
  entity_type         text,
  entity_id           bigint,
  type                text,
  amount              numeric(15,4),
  currency_code       text,
  exchange_rate       numeric(15,6),
  base_amount         numeric(15,4),
  balance_after       numeric(15,4),
  source_type         text,
  source_id           text,
  metadata            jsonb,
  created_at          timestamptz,
  is_reversal         boolean,
  reversed_entry_id   uuid
)
```

### Behaviour

- Filter: `parent_tenant_id = v_books_id`, `entity_type`, `entity_id`.
- Optional `p_operating_tenant_id`: narrow to one child desk.
- Optional `p_search`: `ILIKE` on `source_id`, `metadata->>'note'`, `metadata->>'trx_id'`, `metadata->>'section'`, `source_type`.
- Sort: `created_at DESC`, `id DESC` (matches current UI).
- `is_reversal` / `reversed_entry_id`: from metadata keys `reversal_of` / `reversed_by` (set by reversal RPC).

### UI mapping

Maps to `UniversalWalletLedgerEntry` (+ optional `operating_tenant_id` for future column).

---

## 3. `record_wallet_manual_transaction_for_staff`

Records **Pay / Deposit / Credit / Withdraw** from [`WalletActionModal.vue`](../../../web/src/modules/wallet/components/WalletActionModal.vue). Replaces client `walletRepository.recordTransaction` → `record_ledger_transaction`.

### Signature

```sql
record_wallet_manual_transaction_for_staff(
  p_tenant_id           bigint,
  p_action_type         text,    -- pay | deposit | credit | withdraw
  p_primary_entity_type text,
  p_primary_entity_id   bigint,
  p_amount              numeric,
  p_currency_code       text    DEFAULT 'BDT',
  p_exchange_rate       numeric DEFAULT 1.000000,
  p_category            text,
  p_payment_method      text,
  p_reference_id        text    DEFAULT NULL,
  p_note                text    DEFAULT NULL,
  p_counterparty_entity_type text DEFAULT NULL,
  p_counterparty_entity_id   bigint DEFAULT NULL,
  p_target_bucket       text    DEFAULT 'available'
)
RETURNS jsonb
```

### `p_action_type` → ledger movements

| Action | Primary wallet (page context) | Counterparty (optional) | Movement |
| :--- | :--- | :--- | :--- |
| **deposit** | Credit primary | — | External cash in → primary `credit` |
| **withdraw** | Debit primary | — | Primary `debit` (external payout) |
| **credit** | Credit primary | If company wallet + counterparty: credit **counterparty** only (store credit to recipient) | See below |
| **pay** | Debit **tenant** books cash | Credit counterparty when set | Double-entry when paying from company |

**Company wallet + pay/credit with counterparty** (`p_primary_entity_type = 'tenant'`):

- **pay:** `debit` tenant (`entity_id = v_books_id`) + `credit` counterparty (vendor/customer/courier/cargo).
- **credit:** `credit` counterparty only (non-cash store credit to recipient).

**Non-tenant wallet page (e.g. courier detail):**

- **deposit / withdraw / credit:** apply to **primary** entity only (single leg).
- **pay:** v1 — `debit` primary only; UI label “from company” should move to company wallet pay flow in a follow-up, OR RPC debits tenant + credits primary in one call (recommended: **tenant debit + primary credit** when action is pay and primary ≠ tenant).

Implement pay from non-tenant pages as **atomic two-leg** inside RPC (tenant debit + primary credit) so money leaves company cash.

### Metadata (stored on ledger rows)

```json
{
  "section": "<p_category>",
  "method": "<p_payment_method>",
  "trx_id": "<p_reference_id>",
  "note": "<p_note>",
  "action_type": "<p_action_type>",
  "transaction_type": "manual_adjustment",
  "label": "<human label from action>",
  "recorded_by": "<current_user_email()>",
  "target_bucket": "available"
}
```

### `source_type` / `source_id`

| Action | `source_type` | `source_id` |
| :--- | :--- | :--- |
| pay | `adjustment` or `vendor_purchase` if category `vendor_purchase` | `p_reference_id` or generated `MAN-PAY-<uuid>` |
| withdraw | `payout` | reference or `MAN-WD-<uuid>` |
| deposit | `adjustment` | reference or `MAN-DEP-<uuid>` |
| credit | `adjustment` | reference or `MAN-CR-<uuid>` |

Both legs share same `source_id` when double-entry.

### Validation

- `p_amount > 0`, `p_exchange_rate > 0`.
- Withdraw / pay: sufficient `available_balance` on debited wallet (unless tenant overdraft allowed).
- Counterparty required when `p_action_type IN ('pay','credit')` AND `p_primary_entity_type = 'tenant'`.
- Idempotency optional: reject duplicate `p_reference_id` within books if reference provided.

### Success JSON

```json
{
  "success": true,
  "ledger_entry_ids": ["uuid", "uuid"],
  "primary_account": { "available_balance": 0, "pending_balance": 0, "locked_balance": 0, "total_balance": 0 },
  "counterparty_account": { ... }
}
```

### Errors

Insufficient balance, access denied, invalid action, missing counterparty.

**Internal:** call updated `record_ledger_transaction` with `p_parent_tenant_id`, `p_operating_tenant_id` — do not duplicate balance math.

---

## 4. `reverse_wallet_ledger_entry_for_staff`

“Edit” / revert button on [`UniversalWalletLedgerTable.vue`](../../../web/src/modules/wallet/components/UniversalWalletLedgerTable.vue). **Does not UPDATE** original row.

### Signature

```sql
reverse_wallet_ledger_entry_for_staff(
  p_tenant_id       bigint,
  p_ledger_entry_id uuid,
  p_reason          text,
  p_reference_id    text DEFAULT NULL
)
RETURNS jsonb
```

### Behaviour

1. Load original entry; verify `parent_tenant_id = v_books_id` and caller auth.
2. Reject if `metadata.reversed_by` already set or `metadata.reversal_of` present.
3. Reject reversals on system-generated dropship rows unless `metadata.allow_manual_reversal = true` (default: block `source_type = 'shop_order'` unless superadmin).
4. Insert opposite `type` with same `amount`/`base_amount`, `metadata`:

```json
{
  "reversal_of": "<original id>",
  "transaction_type": "manual_reversal",
  "note": "<p_reason>",
  "trx_id": "<p_reference_id>",
  "recorded_by": "<email>"
}
```

5. Stamp original: `metadata.reversed_by = new id`.

### Success

```json
{
  "success": true,
  "reversal_entry_id": "uuid",
  "account": { "available_balance": ..., "total_balance": ... }
}
```

---

## Frontend wiring (separate PR)

| UI | RPC |
| :--- | :--- |
| `initializePage` | `get_wallet_detail_for_staff` |
| `useWalletQuery` | `list_wallet_ledger_for_staff` |
| `handleActionSubmit` | `record_wallet_manual_transaction_for_staff` |
| `onRevertClick` | `reverse_wallet_ledger_entry_for_staff` |
| `WalletActionModal` destination dropdown | keep `list_wallet_entities_for_staff` per type (or slim picker RPC later) |

### Query keys

```text
['wallet', 'detail', { booksTenantId, entityType, entityId }]
['wallet', 'ledger', { booksTenantId, entityType, entityId, search, offset }]
```

### Types

Add `WalletDetailResponse`, `RecordManualTransactionPayload`, `ReverseLedgerPayload` in `web/src/modules/wallet/types/index.ts` after `backend:types`.

---

## Implementation checklist

- [ ] Migration + function definitions in `supabase/schemas/public.sql`
- [ ] `GRANT EXECUTE … TO authenticated`
- [ ] `pnpm run backend:types`
- [ ] `walletRepository.getDetailForStaff`, `listLedgerForStaff`, `recordManualTransaction`, `reverseLedgerEntry`
- [ ] Remove direct table reads from `UniversalWalletPage.fetchEntityName`
- [ ] Wire revert modal (reason required) replacing toast-only `onRevertClick`
- [ ] Verify order 37 courier wallet after parent-books data + RPCs

---

*Spec created 2026-08-27. No SQL in repo yet.*
