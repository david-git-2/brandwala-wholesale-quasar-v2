# Vendor Lifecycle & Workflow Specification

This document details the step-by-step business flow for vendor setup and management, mapping each stage to its corresponding APIs and RPCs.

---

## Lifecycle Overview

```mermaid
flowchart TD
    subgraph Stage0["Stage 0: Tenant default"]
        Z0["Parent tenant create / ensure_default_vendor"]
        Z1["Insert DEFAULT vendor + wallet"]
        Z0 --> Z1
    end

    subgraph Stage1["Stage 1: Provisioning"]
        A["Call RPC: create_vendor_with_wallet"]
        B["Create Vendor Record & Wallet Account"]
        A --> B
    end

    subgraph Stage2["Stage 2: Profile Maintenance"]
        C["Update Vendor Profile (REST API)"]
        B --> C
        Z1 --> C
    end

    subgraph Stage3["Stage 3: Deletion & Safety Check"]
        D{"Wallet Balance? / is_default?"}
        E["Delete Vendor & Wallet"]
        F["Block Deletion (Keep Trail / protect DEFAULT)"]
        C --> D
        D -- "Balance = 0 and not default" --> E
        D -- "Balance > 0 or is_default" --> F
    end
```

---

## Stage 0: Auto-provision default vendor

* **When**:
  * Superadmin creates a **parent** tenant via `create_tenant_for_superadmin` (child tenants skipped).
  * Migration / ops backfill calls `ensure_default_vendor` for every existing parent tenant.
* **What**: Idempotent insert of `code = 'DEFAULT'`, `name = 'Default Vendor'`, `is_default = true`, plus zero-balance `wallet_accounts` row. `market_code` resolved from an existing tenant vendor market, else a stable active `markets.code` (prefer `GB` / `BD` / `US`).
* **Used by**:
  * Shipment create dialog prefill
  * Shipment draft / header RPC fallback when `p_vendor_id` is null
* **RPC**: `ensure_default_vendor(p_tenant_id)` → returns vendor `id`

---

## Stage 1: Vendor & Wallet Provisioning

* **Action**: Admin / Manager adds a new supplier/vendor to the tenant.
* **Execution**: Single RPC function provisions vendor record (`is_default = false`) and creates an initial zero-balance `wallet_account` (`entity_type: 'vendor'`) in 1 atomic transaction.
* **API / RPC Used**:
  * [create_vendor_with_wallet.md](rpc/create_vendor_with_wallet.md) (`supabase.rpc('create_vendor_with_wallet', ...)`)

---

## Stage 2: Profile Editing & Maintenance

* **Action**: User updates contact info, address, or vendor details.
* **API Used**:
  * [vendor_api.md](api/vendor_api.md) (`supabase.from('vendors').update(...)`)

---

## Stage 3: Deletion & Financial Safety

* **Action**: User attempts to remove a vendor.
* **Safety Rule**:
  * **`is_default` / `code = 'DEFAULT'`**: Do not delete — required for shipment header fallback.
  * **Balance = 0** (non-default): Deletion succeeds and cleans up empty wallet (`ON DELETE CASCADE`).
  * **Balance > 0**: System blocks deletion to prevent untracked balance / audit trail loss.
* **API Used**:
  * [vendor_api.md](api/vendor_api.md) (`supabase.from('vendors').delete(...)`)
