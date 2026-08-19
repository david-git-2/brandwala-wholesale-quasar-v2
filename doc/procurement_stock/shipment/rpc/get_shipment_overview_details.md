# Composite RPC: `get_shipment_overview_details`

## Overview
Consolidates all shipment-specific data queries for the shipment overview & details page into a single PostgreSQL RPC, reducing 12+ API roundtrips to 1.

## Signature
```sql
CREATE OR REPLACE FUNCTION get_shipment_overview_details(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public;
```

## Input Parameters
| Parameter | Type | Description |
| :--- | :--- | :--- |
| `p_shipment_id` | `bigint` | ID of the shipment to load |

## Execution Logic
1. Look up `global_shipments` by `p_shipment_id`. If not found, raises an exception.
2. Calls `ensure_global_shipment_cost_entries_from_header(p_shipment_id)` internally to guarantee cost entries are synced.
3. Queries `global_shipment_sections` joined with `vendors`.
4. Queries `global_shipment_items`.
5. Queries `global_shipment_boxes`.
6. Queries `global_shipment_cost_entries`.
7. Queries `shipment_progress_flow_stages` for the shipment's active flow.
8. Assembles and returns a single unified JSON object.

## Response Shape
```json
{
  "shipment": {
    "id": 16,
    "name": "SHP-2026-001",
    "status": "in_transit",
    "type": "standard",
    "progress_flow_id": 1,
    "progress_tag_id": 3,
    "cargo_company_id": 5,
    "vendor_id": 2
  },
  "sections": [
    {
      "id": 10,
      "shipment_id": 16,
      "vendor_id": 2,
      "invoice_number": "INV-9981",
      "vendor": { "id": 2, "name": "Vendor A" }
    }
  ],
  "items": [],
  "boxes": [],
  "cost_entries": [],
  "flow_stages": [
    { "id": 1, "flow_id": 1, "name": "Dispatched", "sort_order": 1, "color": "blue" },
    { "id": 2, "flow_id": 1, "name": "In Customs", "sort_order": 2, "color": "orange" }
  ]
}
```
