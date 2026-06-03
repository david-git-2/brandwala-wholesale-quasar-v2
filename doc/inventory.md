# Inventory Module

The `inventory` module provides the stock source-of-truth for e-commerce and shipment-driven stock control.

## Key Features

- **Store item-level cost and product linkage**: Link inventory items to products and track individual purchase costs.
- **Track stock quantities** by condition:
  - `available` (usable stock)
  - `reserved` (allocated to pending orders)
  - `damaged` (physically broken/defective)
  - `stolen` (shrinkage)
  - `expired` (out of date)
  - `open box` (returned or missing packaging, but sellable)
- **Track inventory movements** for audits and transaction logging.
- **Unified Inventory Notes**: Document defects, return reasons, and warehouse instructions at the SKU, batch, or transaction level.

---

## E-commerce & Invoice Integration

- Commerce invoice rows select a specific inventory item (batch).
- Selected inventory cost is copied to the commerce order item cost for accurate accounting.
- Stock decreases on invoice assignment and increases on de-assignment or returns.
- Returns can be routed back to the available pool, open box pool, or the damaged pool based on inspection status.

---

## Batch Lifecycle & Split-Receiving

To maintain precise pricing control and trace defects, the inventory system supports **Split-Batching on Receipt**:

1. **Default/Primary Batch**: On shipment receipt, standard sellable items are created as the primary batch (e.g., `available_quantity = 20`).
2. **Defect Sub-Batches**: If a shipment arrives with items in different conditions (e.g. damaged box, expired, or loose packaging), they are split into separate `inventory_items` rows. This allows:
   - Setting a custom discounted sell price on the damaged-box sub-batch.
   - Setting a `$0.00` price and writing off the cost of the expired sub-batch.
   - Attaching distinct notes explaining why the sub-batch exists.

---

## Schema Reference

### 1. `inventory_items`
Represents a unique stock lot or batch (manual entry or shipment source).
* `id` (bigint, primary key)
* `tenant_id` (bigint, references `tenants`)
* `source_type` (text: `'manual'` or `'shipment'`)
* `source_id` (bigint, null)
* `name` (text)
* `cost` (numeric)
* `manufacturing_date` / `expire_date` (date, null)
* `status` (text: `'active'` or `'inactive'`)

### 2. `inventory_stocks`
Holds current stock quantity states for a specific `inventory_item`.
* `id` (bigint, primary key)
* `inventory_item_id` (bigint, unique, references `inventory_items`)
* `available_quantity` (integer)
* `reserved_quantity` (integer)
* `damaged_quantity` (integer)
* `stolen_quantity` (integer)
* `expired_quantity` (integer)
* `open_box_quantity` (integer)

### 3. `inventory_notes` (New Table)
Polymorphic note table to attach instructions, defect details, and return reasons.
```sql
create table public.inventory_notes (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  
  -- Polymorphic relationships (at least one populated)
  product_id bigint null references public.products(id) on delete cascade,             -- General SKU level
  inventory_item_id bigint null references public.inventory_items(id) on delete cascade, -- Batch/Lot level
  movement_id bigint null references public.inventory_movements(id) on delete cascade,  -- Transaction level

  -- Note Metadata
  category text not null check (
    category in (
      'general', 
      'packaging_defect', 
      'product_defect', 
      'return_reason', 
      'warehouse_instruction'
    )
  ),
  content text not null,
  
  created_by uuid null references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
```

### 4. `inventory_movements`
The transaction audit log for every quantity change.
* `id` (bigint, primary key)
* `inventory_item_id` (bigint)
* `type` (text: `'received'`, `'sold'`, `'reserved'`, `'unreserved'`, `'damaged'`, `'stolen'`, `'expired'`, `'adjustment'`)
* `quantity` (integer)
* `previous_quantity` / `new_quantity` (integer)
* `note` (text, null)
* `created_by` (uuid)
* `created_at` (timestamptz)

---

## End-to-End Workflow Examples

### Warehouse Damage Event
1. Two units are dropped and damaged in the warehouse.
2. In `inventory_stocks` for that batch: `available_quantity` decreases by 2, and `damaged_quantity` increases by 2.
3. An `inventory_movement` row is created (type: `'adjustment'`).
4. An `inventory_notes` row is created:
   - `inventory_item_id` = [Batch ID]
   - `movement_id` = [Movement ID]
   - `category` = `'product_defect'`
   - `content` = *"2 units dropped from Shelf C; protective packaging cracked."*

### Customer Return Event
1. Customer returns 1 unit with a broken zipper.
2. Admin processes the return, choosing **"Mark as Damaged"**.
3. In `inventory_stocks` for the original batch: `damaged_quantity` increases by 1.
4. An `inventory_movement` row is created (type: `'adjustment'`).
5. An `inventory_notes` row is created:
   - `inventory_item_id` = [Batch ID]
   - `movement_id` = [Movement ID]
   - `category` = `'return_reason'`
   - `content` = *"Returned by customer on Invoice #1023. Zipper is split."*
