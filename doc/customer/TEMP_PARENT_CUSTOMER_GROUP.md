# TEMP — Customer group redesign (parent-owned)

**Status:** decision + redesign. Not implemented. Do not treat as current runtime behavior.

**As-built module:** [`CUSTOMER.md`](./CUSTOMER.md) · account RPC [`CUSTOMER_ACCOUNT_SUMMARY_RPC.md`](./CUSTOMER_ACCOUNT_SUMMARY_RPC.md)

**Locked 2026-09-10**

1. The **customer group** (B2B company) lives on the **parent / books tenant**, not on each child.
2. Keep **group ≠ billing profile**. Lock **one profile per group**.
3. Children **grant shops and sell**. They do not clone the company.

[`TENANT_AUTH.md`](../tenant_auth/TENANT_AUTH.md) still says children own `customer_groups` — this file is the target until those docs are merged.

When implemented: merge into `CUSTOMER.md` + `TENANT_AUTH.md`, then delete this file.

---

## 1. Decision

| Fact | Target |
| :--- | :--- |
| Who owns the customer group | **Parent** (`customer_groups.tenant_id` = books tenant). Standalone = itself. |
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
  customer_groups                 ← hub “Customer”
    └── billing_profiles (1:1)    ← Account: invoices, wallet, dues, demand, after-sales merchant
    └── members                   ← shop logins
    └── gift / costing (optional) ← commercial extras on the company

Child desk / shop
  shops
    └── shop_customer_group_access  ← may this group use this shop? flags, tier, shop credit
  shop_carts / shop_orders          ← operating tenant = child
                                      stamp group id + profile id at checkout

recipient_profiles                  ← delivery (optional group link later)
```

Staff create a **Customer** from parent or child desk; the row is saved on **parent**. Children only grant shops.

### Locked rules

1. One billing profile per group on the books tenant. Unique `(tenant_id, customer_group_id)` where group is set.
2. `create_customer_account` always inserts group + profile + wallet. `tenant_id` on group and profile = `resolve_parent_tenant_id(p_tenant_id)`.
3. No second profile on sister children. Wallet on parent books; child is `operating_tenant_id` only.
4. Stamp `billing_profile_id` on the shop order at checkout. Do not re-resolve later.
5. Shop session = this email + **this shop’s granted group**. No silent `limit 1`. Permissions do not `bool_or` across two groups.
6. Access row required to enter a shop. Credit limit + price tier stay on `shop_customer_group_access` (per shop). Group-wide AR limit (if added) lives on the **profile**.
7. Recipients stay separate. Do not hang wallet or AR on recipient id.
8. UI words: **Customer** (group), **Account** (billing profile). No new “middleman.” Table names can stay.
9. Hub = CRM. Access Control = extra grants only. No “link billing profile.”

### Field ownership

| On the group | On the billing profile |
| :--- | :--- |
| Company name, accent color, active | Contact name, admin email, phone, address |

One General-tab write updates both.

---

## 4. What relates (and how)

**Rule:** company + shop rights hang on the **group**. Money hangs on the **profile** (1:1 with the group). Delivery hangs on **recipients**.

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
- `current_customer_group_id` lowest-id pick; `get_shop_permissions_for_customer` ORs across groups.

---

## 5. Id map (after this lands)

| Step | Id |
| :--- | :--- |
| Staff create / hub list | Group id; `group.tenant_id` = parent |
| Grant shop | Group id on access row; `shop.tenant_id` = child |
| Shop login | Member email → granted group for that shop |
| Cart | Group id; `cart.tenant_id` = child |
| Checkout | Resolve the **one** profile → store group id + profile id |
| Invoice / collect / wallet / demand / after-sales merchant | Profile id only |

If a page needs the other id, follow the 1:1 link. No second picker.

---

## 6. As-built vs target

| Topic | As-built now | Target |
| :--- | :--- | :--- |
| `customer_groups.tenant_id` | Operating / child | Books / parent |
| `TENANT_AUTH.md` ownership | Child owns groups + profiles | Parent owns group + profile; child owns shops + orders |
| Many profiles per group | Allowed; resolver `limit 1` | Forbidden |
| Access Control “link billing profile” | Exists | Remove; create always links |
| Access matrix group list | `customer_groups.tenant_id = shop tenant` | Groups on **books** tenant of that shop |
| Account summary | All family profiles; “primary” guess | One profile id; dues + wallet same row |

---

## 7. Redesign phases

Ship **1 then 2**. That is the redesign. 3 and 4 are cleanup.

### Phase 1 — Lock money + parent ownership

**Goal:** New customers live on parent. One profile. Create / list / account use that.

- `create_customer_account`: group + profile `tenant_id` = `resolve_parent_tenant_id(p_tenant_id)`. Wallet already parent books.
- Unique: one `billing_profiles` row per `(tenant_id, customer_group_id)` where group is set.
- Backfill: move or merge child-owned groups/profiles (keep the row with invoices/wallet).
- `resolve_billing_profile_for_customer_group`: lookup that one row. Drop family-wide hunt after backfill.
- `get_customer_account_summary_for_staff` / `list_customer_accounts`: books tenant; one profile.
- Stop Access Control **Link billing profile**.

Until this is green, do not change shop login.

### Phase 2 — Child sells, parent customer

**Goal:** Child shops grant parent groups. Login cannot pick the wrong company.

- Access matrix lists groups where `customer_groups.tenant_id` = books of this shop’s tenant.
- `get_shop_permissions_for_customer` / `current_customer_group_id` / `check_shop_login_access`: join **this shop’s** access row. Two groups for one email → that shop’s grant, or fail. Never OR flags.
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
