# TEMP — Customer group redesign (parent-owned)

**Status:** decision + redesign. Not implemented. Do not treat as current runtime behavior.

**As-built module:** [`CUSTOMER.md`](./CUSTOMER.md) · account RPC [`CUSTOMER_ACCOUNT_SUMMARY_RPC.md`](./CUSTOMER_ACCOUNT_SUMMARY_RPC.md)

**Locked 2026-09-10**

1. The **customer group** (B2B company) lives on the **parent / books tenant**, not on each child.
2. Keep **group ≠ billing profile**. At most **one profile per group**. The group is optional: a one-off invoice can use a profile with no company.
3. Children **grant shops and sell**. They do not clone the company.

[`TENANT_AUTH.md`](../tenant_auth/TENANT_AUTH.md) still says children own `customer_groups` — this file is the target until those docs are merged.

When implemented: merge into `CUSTOMER.md` + `TENANT_AUTH.md`, then delete this file.

---

## 1. Decision

| Fact | Target |
| :--- | :--- |
| Who owns the customer group | **Parent** (`customer_groups.parent_tenant_id` = books tenant). Standalone = itself. |
| Who owns shops, carts, shop orders | **Child** (operating desk). |
| Who owns AR / wallet books | **Parent** (already true for invoices + wallet `parent_tenant_id`). |
| Child’s job | **Grant shop access** and sell. Not a second group. |

Sister concerns are **channels** (wholesale desk, dropship shop), not separate buyer masters.

**Exception (not default):** a child is a real separate legal company with its own AR and must not see the other desk’s buyers → group stays on that child. Product must say so explicitly.

---

## 2. Why

ERP multi-company:

- **Party / customer master** → holding / books (parent)
- **Sales relationship** → selling unit (child shop)
- **AR** → books entity (parent)

Per-store customers (Shopify) are the wrong pattern: one warehouse, one book, several desks.

Child-owned groups are why checkout **searches the family** for a billing profile (`resolve_billing_profile_for_customer_group`). That fallback is a patch. Parent-owned group + one money account removes it.

Do **not** merge group and profile. Shop access, carts, members are group-shaped. Invoices and wallet are profile-shaped.

---

## 3. Target shape

```text
Parent books
  customer_groups                 ← hub “Customer” (B2B company)
    └── billing_profiles (0..1)   ← Account when this is a repeat company
    └── members                   ← shop logins
    └── gift / costing (optional)

  billing_profiles                ← also standalone: one-off invoice / walk-in AR
                                    customer_group_id null, parent_tenant_id = books

Child desk / shop
  shops
    └── shop_customer_group_access  ← company only; no shop login without a group
  shop_carts / shop_orders          ← stamp group id when present + profile id

recipient_profiles                  ← delivery
```

Staff create a **Customer** from parent or child desk; the row is saved on **parent**. Children only grant shops.

### Target tables

**`customer_groups`** (company). No `tenant_id`. Books scope is `parent_tenant_id`. Soft delete via `deleted_at`.

```text
id                 bigint PK
name               text NOT NULL
parent_tenant_id   bigint NOT NULL   -- books tenant; standalone = itself
is_active          boolean NOT NULL DEFAULT true
deleted_at         timestamptz       -- null = live
accent_color       text
created_at         timestamptz NOT NULL
updated_at         timestamptz NOT NULL
```

**`billing_profiles`** (account / money). Books scope is **`parent_tenant_id`** (always). Drop operating `tenant_id` and `color`. `customer_group_id` is optional.

```text
id                 bigint PK
parent_tenant_id   bigint NOT NULL         -- books tenant
customer_group_id  bigint                  -- FK customer_groups; null = one-off
name               text NOT NULL           -- payer name; on create = group name
email              text
phone              text NOT NULL           -- unique per parent_tenant_id
address            text
created_at         timestamptz NOT NULL
updated_at         timestamptz NOT NULL
```

Unique: one profile per group — `UNIQUE (customer_group_id) WHERE customer_group_id IS NOT NULL`.

Unique phone: `UNIQUE (parent_tenant_id, phone)` (normalize before write).

When `customer_group_id` is set, `parent_tenant_id` must match `customer_groups.parent_tenant_id`.

Wallet stays: `wallet_accounts.parent_tenant_id` = books, `entity_type = customer`, `entity_id` = profile id. One-off profiles can still have a wallet.

### Locked rules

1. At most one billing profile per group. Many profiles may have `customer_group_id` null (one-off invoices).
2. Hub **Create Customer** asks only **group name + phone**. RPC inserts group + profile + wallet. Profile name = group name; profile phone = that phone. No member on create. Invoice create may insert a profile with no group (name + phone).
3. No second profile on sister children for the same company. Wallet on parent books.
4. Stamp `billing_profile_id` on the shop order at checkout. Do not re-resolve later.
5. Shop session = this email + **this shop’s granted group**. No silent `limit 1`. Permissions do not `bool_or` across two groups. If two groups are granted on this desk, the buyer picks one (`x-selected-customer-group-id`).
6. Access row required to enter a shop. Credit limit + price tier stay on `shop_customer_group_access` (per shop). Group-wide AR limit (if added) lives on the **profile**.
7. Recipients stay separate. Do not hang wallet or AR on recipient id.
8. UI words: **Customer** (group), **Account** (billing profile). No new “middleman.” Table names can stay.
9. Hub = CRM. Access Control = extra grants only. No “link billing profile.”

### Field ownership

| On the group | On the billing profile |
| :--- | :--- |
| Company name, accent color, active | Contact name, email, **phone** (unique per books), address |

Hub General-tab write updates both when the profile has a group. One-off profiles are edited from the invoice / billing picker, not the Customer hub.

---

## 4. What relates (and how)

**Rule:** company + shop rights hang on the **group** (when there is a company). Money hangs on the **profile**. Delivery hangs on **recipients**. A one-off invoice uses a profile with no group.

### Keep on the group

| Thing | Table / path |
| :--- | :--- |
| Members | `customer_group_members` |
| Member extra grants | `customer_group_member_grants` + `tenant_role_id` |
| Shop grant | `shop_customer_group_access` |
| Shop cart | `shop_carts.customer_group_id` |
| Shop order (who shopped) | `shop_orders.customer_group_id` (+ stamped profile) |
| Gift rules | `gift_rules.customer_group_id` (optional) |
| PBC costing files | `costing_files.customer_group_id` |
| Catalog negotiate | Access flag `can_negotiate` + group session |

### Through the profile (do not add a second group id)

| Thing | Today |
| :--- | :--- |
| Wallet | `entity_type = customer`, `entity_id = billing_profile.id` |
| Invoices / collect / dues | `billing_profile_id` |
| Demand wait-list | `customer_demand_bucket_items.billing_profile_id` |
| Dropship settlement / merchant payout | profile on the order |
| After-sales merchant | `merchant_billing_profile_id` |

Hub opens the **group**. Account tab follows the **one** profile.

### Should relate later (not required to ship Phases 1–2)

| Thing | How |
| :--- | :--- |
| Saved recipients | Optional `customer_group_id` on `recipient_profiles` (or join). Desk retail can stay global. |
| Group-wide credit | On the **profile**. Shop-row limit stays “this shop’s cap.” |
| Notes / documents / extra contacts | Hang on the **group** if added. |

### Should not hang on the group

Stock, shipments, vendors, invoice brand, courier/cargo, staff memberships, end-customer as AR (recipient or retail snapshot).

### Leftover FKs (do not design new work on these)

`store_access`, `carts`, `orders`, `commerce_cart`, `commerce_orders`, `koba_carts`, `koba_orders`. Live path is shop_order.

### Clutter to fold (Phases 3–4)

- Two shop-flag tables: `shop_customer_group_access` vs `customer_group_shop_profiles`. Access matrix is source of truth.
- Three member-right layers: `customer_group_role`, `tenant_role_id`, `customer_group_member_grants`. Hub Members = name/email/role/active. Access Control = extra grants.
- `current_customer_group_id` header or single-candidate pick; `get_shop_permissions_for_customer` must not OR across groups.

---

## 5. Id map (after this lands)

| Step | Id |
| :--- | :--- |
| Staff create / hub list | Group id; `group.parent_tenant_id` = parent. Hide `deleted_at` set. One-off profiles are not hub customers. |
| Grant shop | Group id on access row; `shop.tenant_id` = child |
| Shop login | Member email → granted group(s) for that shop tenant; picker if more than one |
| Cart | Group id; `cart.tenant_id` = child |
| Checkout | Resolve the **one** profile → store group id + profile id |
| Invoice / collect / wallet / demand / after-sales merchant | Profile id only |

If a page needs the other id, follow the group link when it exists. One-off profiles have no group.

---

## 6. As-built vs target

| Topic | As-built now | Target |
| :--- | :--- | :--- |
| Group tenant column | `customer_groups.tenant_id` (operating / child) | `customer_groups.parent_tenant_id` (books). Drop `tenant_id`. |
| Soft delete | None (hard delete / `is_active`) | `deleted_at` on group; list RPCs skip deleted |
| Profile books column | `tenant_id` + `parent_tenant_id` | Keep **`parent_tenant_id`**. Drop operating `tenant_id` and `color`. |
| Group on profile | Optional; many profiles per group | Optional. Unique when set. Null = one-off invoice AR. |
| `TENANT_AUTH.md` ownership | Child owns groups + profiles | Parent owns group + profile; child owns shops + orders |
| Many profiles per group | Allowed; resolver `limit 1` | Forbidden. One-off profiles have no group. |
| Access Control “link billing profile” | Exists | Remove; create always links |
| Access matrix group list | `customer_groups.tenant_id = shop tenant` | Groups where `parent_tenant_id` = books of that shop |
| Create customer | Name, admin, email, color, phone optional | **Name + phone only.** Profile + wallet auto. Members later. |
| Company key | Tenant-wide admin email | Unique **phone** on books (`parent_tenant_id` + phone) |

---

## 7. Redesign phases

Ship **1 then 2**. That is the redesign. 3 and 4 are cleanup.

### Phase 1 — Lock money + parent ownership

**Goal:** New customers live on parent. One profile. Create / list / account use that.

- `create_customer_account(p_tenant_id, p_group_name, p_phone)`: group + profile + wallet. Both `parent_tenant_id` = books. Profile `name` = group name. Profile `phone` required, unique on `(parent_tenant_id, phone)`. No admin member. Accent default.
- Unique: one profile per `customer_group_id` where the group is set. Unique `(parent_tenant_id, phone)`. Null group allowed.
- Invoice / billing UI may create a profile with `customer_group_id` null (one-off AR: name + phone). No members, no shop grant.
- Backfill: set group `parent_tenant_id`; drop group `tenant_id`. Profile: keep `parent_tenant_id`, drop `tenant_id` and `color`. Merge extra profiles that share a group. Add group `deleted_at`.
- `resolve_billing_profile_for_customer_group`: that one row by `customer_group_id`. Drop family-wide hunt after backfill.
- `get_customer_account_summary_for_staff` / `list_customer_accounts`: `cg.parent_tenant_id = books`; `deleted_at is null`; one profile.
- Stop Access Control **Link billing profile**.

Until this is green, do not change shop login.

### Phase 2 — Child sells, parent customer

**Goal:** Child shops grant parent groups. Login cannot pick the wrong company.

- Access matrix lists groups where `customer_groups.parent_tenant_id` = books of this shop’s tenant and `deleted_at is null`.
- `get_shop_permissions_for_customer` / `current_customer_group_id` / `check_shop_login_access`: join **this shop’s** access row. Two groups for one email on this desk → company picker. Never OR flags. Never silent first-row pick.
- Checkout keeps stamping profile via Phase 1 resolver.
- Delete group: still block on shop orders + invoices; also wallet balance / open carts.

### Phase 3 — One rights surface, one people surface

- Access tab writes `shop_customer_group_access` only. Hide or retire `customer_group_shop_profiles` as a second editor.
- Hub Members: name, email, role, active. Role → default tenant role.
- Access Control Customer Groups: grants only, not a second CRM.

### Phase 4 — Words + leftovers

- UI: Customer / Account.
- No new features on commerce/koba/store_access.
- Optional: recipient `customer_group_id`; profile-level books credit.

---

## 8. Out of scope (do not redesign)

- Merge group into billing profile
- Move shops to parent
- Wallet keyed by group id
- Recipients as the B2B customer
- Stock / vendors / couriers on the group
