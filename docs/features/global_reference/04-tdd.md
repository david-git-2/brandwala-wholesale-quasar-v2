# Global Reference, Koba Vertical & Central Trash — Technical Design Document (TDD)

## 1. System Architecture & High-Level Design

```mermaid
flowchart TD
    subgraph UI ["Client Layer (Vue 3 / Quasar)"]
        REF_UI["Global Reference Hub & Catalogs"]
        KOBA_UI["Koba Retail Catalog & Cart"]
        TRASH_UI["Central Trash Hub"]
    end

    subgraph State ["TanStack Query & Pinia Stores"]
        RQ_REF["useGlobalCurrenciesQuery<br/>(Cache: 24h)"]
        RQ_KOBA["kobaCartStore / kobaOrderStore"]
        RQ_TRASH["useTrashEntriesQuery<br/>(Optimistic Updates)"]
    end

    subgraph Backend ["Supabase RPC & PostgreSQL"]
        RPC_COMM["calculate_koba_commission()"]
        RPC_TRASH["soft_delete() / restore_from_trash()"]
        CRON_PURGE["cron: purge_expired_trash()"]
    end

    REF_UI --> RQ_REF
    KOBA_UI --> RQ_KOBA
    TRASH_UI --> RQ_TRASH

    RQ_REF --> Backend
    RQ_KOBA --> RPC_COMM
    RQ_TRASH --> RPC_TRASH
    CRON_PURGE --> Backend
```

---

## 2. Core Business Algorithms & State Machines

### 2.1 Koba Profit Sharing & Fee Deductions
When an order item is customized with an adjusted sell price:

$$\text{Markup GBP} = \max(0, \text{Sell Price GBP} - \text{Base List Price GBP})$$

$$\text{Agent Markup Share} = \text{Markup GBP} \times \left(\frac{\text{extra\_profit\_user\_pct}}{100}\right) \times \text{FX Rate}$$

$$\text{Company Markup Share} = \text{Markup GBP} \times \left(\frac{\text{extra\_profit\_company\_pct}}{100}\right) \times \text{FX Rate}$$

$$\text{COD Deduction} = \text{Order Total BDT} \times \left(\frac{\text{cod\_charge\_pct}}{100}\right)$$

$$\text{Net Agent Commission} = \text{Agent Markup Share} - (\text{COD Deduction} + \text{packing\_fee\_flat} + \text{invoice\_fee\_flat})$$

---

### 2.2 Soft Delete & Central Trash Directory Lifecycle

```mermaid
sequenceDiagram
    autonumber
    actor User as Operations Staff
    participant UI as TrashPage / Table Action
    participant RPC as restore_from_trash()
    participant DB_E as Domain Table (e.g. vendors)
    participant DB_T as trash_entries Table

    User->>UI: Click "Restore" on Vendor record
    UI->>RPC: POST /rpc/restore_from_trash { p_trash_id, p_tenant_id }
    RPC->>DB_E: UPDATE vendors SET deleted_at = NULL, deleted_by = NULL WHERE id = entity_id
    RPC->>DB_T: DELETE FROM trash_entries WHERE id = p_trash_id
    RPC-->>UI: { success: true, restored_entity_type: 'vendor' }
    UI->>UI: Invalidate ['trash', 'list'] and ['vendors', 'list']
    UI-->>User: Display Success Toast & update UI
```

---

## 3. Frontend Architecture & Caching Strategy

| Domain Query Key | Stale Time | Cache Time | Invalidation Triggers |
| :--- | :--- | :--- | :--- |
| `['global-reference', 'currencies']` | 24 hours | 24 hours | Currency exchange rate update by Superadmin |
| `['global-reference', 'markets']` | 10 minutes | 30 minutes | Market configuration changes |
| `['koba', 'products', filters]` | 60 seconds | 5 minutes | Ingestion of newly scraped catalog items |
| `['koba', 'cart', tenantId]` | 15 seconds | 2 minutes | Item addition, price override, quantity update |
| `['trash', 'list', tenantId]` | 30 seconds | 5 minutes | Move to trash, restore, or permanent purge |

---

## 4. Security, RLS & Edge Cases

### 4.1 Unique Constraint Collision on Restore
- **Problem**: A user deletes a product with SKU `TSHIRT-01`, creates a new product with the same SKU `TSHIRT-01`, and subsequently attempts to restore the original trashed product.
- **Handling**: `restore_from_trash` checks uniqueness before execution. If a conflict occurs, it halts with error code `ERR_DUPLICATE_KEY` and prompts the user to rename or resolve the conflict prior to restoration.

### 4.2 Immutable Financial Trail
- Financial ledgers (`universal_wallets`, `ledger_transactions`), issued invoices (`sales_invoices`), and active in-transit shipments (`global_shipments`) are explicitly barred at the database trigger level from soft-deletion. Any attempt throws an unhandled database exception `ERR_IMMUTABLE_FINANCIAL_RECORD`.
