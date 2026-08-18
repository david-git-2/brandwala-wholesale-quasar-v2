# Product Based Costing — quote then confirm

Staff create a costing file, add products, send a screenshot or PDF, then confirm when the customer accepts. There is **no customer inbox**, notify, or shop order.

**Canon:** this file (UX) · [PROCUREMENT_STOCK.md](../procurement_stock/PROCUREMENT_STOCK.md) (shipment handoff)

Keep costing → parent shipment. Desk invoice stays after receive. Shop is out.

---

## Two phases

| Phase | When | This pass |
|-------|------|-----------|
| **1 Quote** | `pending` / `offered` / `cancelled` (UI: Draft / Offered / Cancelled) | Done |
| **2 Buy & ship** | `confirmed` and later | Later — existing chips still show on old fulfillment files |

```
Create file → Add products → Offer PDF or screenshot → Mark Offered → Confirm order
```

Confirm order sets `status = confirmed` and copies each line’s offered `quantity` into `confirmed_quantity` (edit down if they took less). It does **not** reset qty to 0.

## Quote controls

| Control | What it does |
|---------|----------------|
| **Offer (PDF / Screenshot)** | Opens preview. This is how the quote is sent (WhatsApp, print, etc.). |
| **Offered** (`offered`) | Stamp that you sent the quote. Recalculates prices. Does not send. |
| **Confirm order** | They accepted. Copies offered qty → confirmed qty. Opens Buy & ship later. |

Rates (FX, cargo £/kg, profit %) plus line £ price and product weight drive the ৳ offer. Missing £ or weight is marked on the row; Offer warns if cargo is 0 or lines are incomplete.

## Add products

- Primary CTA on the file is **Add products** (catalog drawer).
- Search first. After typing, **Create "{search}" as a new product** is the first result row — reuses the item form.
- Header **Add Item** is removed so users do not skip search.

## Out of scope this pass

- Buy & ship redesign (`placing_order`, `ready_for_shipment`, invoicing, delivered)
- Create desk invoice from the costing file
- Customer shop inbox, email, or accept RPC
- Requiring `billing_profile_id` in the database
- Help drawer
- Deploying backlog-trigger SQL (`20270829000040`, `20270829000050`) — separate from this UI pass
