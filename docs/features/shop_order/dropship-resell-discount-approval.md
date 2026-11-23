# Dropship resell discount approval (pre-confirm)

## As-built

| Step | Behavior |
| :--- | :--- |
| Cart line | `requested_resell_discount_price_amount`, reason, `resell_discount_requested_at` on `shop_cart_items`. |
| Place order | Any line with discount request → **`resell_discount_requested`**; else **`confirmed`** (`checkout_fixed`) or **`submitted`** (`20261123210000_shop_order_resell_discount_requested_status.sql`). |
| Order lines | Request fields snapshotted on `shop_order_items` at place (`20261123200000_shop_order_item_resell_discount_snapshot.sql`). |
| After place | Shop order detail: status strip + requested resell on invoice paper; **no staff approval RPC yet**. |
| Pipeline (no request) | **`confirmed`** → recipient call (US-4) → **`processing`** → pickup → ship → deliver. |
| Pipeline (with request) | **`resell_discount_requested`** → (staff review, not built) → **`confirmed`** → US-4+ |

## Scope

| In | Out |
| :--- | :--- |
| Dropship orders only | Catalog negotiation statuses |
| Gate when **any** line has a pending resell discount request at place | Per-line partial approve in v1 |
| Staff approve / deny on **`app`** | Auto-approve |
| Deny → confirm at **listed resell** or **cancel** | Changing min-resell floor rules |

**Surfaces:** `shop` (place order, order detail) · `app` (review queue + actions).

**Full design:** this file. **Checkout today:** [spec.md](spec.md) US-1a. **Lifecycle context:** [dropship-lifecycle-guide.md](../../product-scenarios/dropship-lifecycle-guide.md).

## Proposed status

| | |
| :--- | :--- |
| **Enum value (working)** | `resell_discount_requested` on `shop_order_status` |
| **Customer label** | Discount review / Request pending |
| **When** | Place order if any line has `requested_resell_discount_price_amount` set |
| **Skips** | Initial **`confirmed`** until staff resolves review |
| **If no request** | Unchanged: **`confirmed`** or **`submitted`** per shop `order_mode` |

Customer progress strip (dropship): insert **Discount review** before **Confirmed**:  
`resell_discount_requested` → `confirmed` → `processing` → `ready_for_pickup` → `shipped` → `delivered`.

## Place order (customer)

```text
Place order
    │
    ├─ No line has discount request → confirmed (or submitted)   [as-built]
    │
    └─ Any line has discount request → resell_discount_requested
            → Message: review in progress
            → No recipient-call workflow until confirmed
```

**Totals UX (decide before build):** Show **listed resell** and **requested resell** on shop detail; COD face at place should follow **listed** until approve (recommended) — see SO-DR4 in [00-gaps.md](00-gaps.md).

## Staff review (`app`)

**Queue:** `status = resell_discount_requested`.

**Line review:** product, qty, purchase, **listed resell** (`customer_sell_price_amount`), **requested resell**, reason, requested at.

| Action | Result |
| :--- | :--- |
| **Approve** | Apply approved resell on lines → **`confirmed`** → US-4+ pipeline |
| **Deny — confirm at listed resell** | Clear/ignore request snapshot; keep listed resell → **`confirmed`** |
| **Deny — cancel** | **`cancelled`** + required `cancel_reason` |

**Approve (v1 recommended):** Set `customer_sell_price_amount` to approved requested price per line; store audit (`resell_discount_reviewed_at`, reviewer, `resell_discount_decision = approved` on order).

**Deny — listed resell:** Null request fields on lines (or `decision = denied_use_listed`); totals from listed resell only.

## Status transitions

```text
[place + discount request] → resell_discount_requested
        ├─ approve ──────────────→ confirmed → processing → …
        ├─ deny + confirm listed ──→ confirmed → processing → …
        └─ deny + cancel ──────────→ cancelled
```

Rules:

- No `resell_discount_requested` → `processing` without passing **`confirmed`**.
- `confirmed` → `processing` still requires `recipient_verified_at` (US-4).

## Backend

| Piece | Notes |
| :--- | :--- |
| Enum | **Done** — `resell_discount_requested` on `shop_order_status` |
| `submit_dropship_order_from_cart` | **Done** — branch on cart lines with request |
| RPC | **Done** — `finalize_dropship_resell_discount_review` (per-line `use_requested` \| `use_listed` \| `custom`); cancel via `cancel_shop_order_dropship` |
| Lists | Staff filters include review status |
| Customer RPC | `get_customer_shop_order` exposes status + line request fields |

Optional order columns: `resell_discount_reviewed_at`, `resell_discount_reviewed_by`, `resell_discount_decision`.

## Frontend

| Surface | Work |
| :--- | :--- |
| Shop | **Done** — post-place toast; order detail status strip + line requests |
| App | **Done** — `DropshipResellDiscountReviewPanel` on staff order detail; list filter **Discount review** |

## Edge cases

| Case | v1 rule |
| :--- | :--- |
| Some lines with request, some without | Whole order → review if **any** request |
| Request cleared on cart after place | Line snapshot on order is truth |
| Staff edits resell while in review | Out of v1 or admin-only override RPC |

## Spec story (track in spec.md)

### US-1b: Dropship resell discount review

- [x] Place with any line request → `resell_discount_requested` (not `confirmed`).
- [x] Staff approve → apply prices → `confirmed` → US-4+.
- [x] Staff deny → confirm at listed resell **or** cancel with reason.
- [ ] Shop shows review state and requested vs listed resell.

## Product scenario (optional)

In [dropship-lifecycle-guide.md](../../product-scenarios/dropship-lifecycle-guide.md) Path A: **DL1a** — discount request at place → desk approval → then DL2 recipient call at `confirmed`.