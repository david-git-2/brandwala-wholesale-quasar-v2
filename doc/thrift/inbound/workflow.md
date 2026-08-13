# Thrift Inbound (shipment & boxes) — Workflow

Part of [Thrift](../README.md). Overview: [../workflow.md](../workflow.md).

Schema: [schema.md](./schema.md)

---

## Workflow

1. Create shipment header (FX, cargo, ops totals, default markup, optional tag override).
2. Add named boxes under the shipment.
3. As stocks exist, client costing preview recalculates — see [../stock/costing.md](../stock/costing.md). Landed cost is **not** stamped on stock.

**APIs:**
- [api/thrift_shipment_api.md](./api/thrift_shipment_api.md)
- [api/thrift_box_api.md](./api/thrift_box_api.md)
