# Sales models

One platform, several ways to sell. Do not mix stock tables across models.

| Model | Stock | Money |
| --- | --- | --- |
| BW (wholesale) | Parent warehouse lots | Bills & pays — [Wholesale](/docs/modules/wholesale) |
| Pre-order | No lot until inbound receive | Quote → demand → Delivery close → bills — [PBC](/docs/modules/product-based-costing) |
| K-beauty | Own koba tables | Commission settings; not BW FIFO desk |
| Thrift | Own thrift garments | Thrift POS — [Thrift](/docs/modules/thrift) |

Dropship is a **channel of BW**, not a separate company type — [Dropship](/docs/modules/dropship).

## Thrift vs BW

Thrift runs under `/:slug/app/thrift/*` with its own stock, POS, and shipments. It does **not** use `global_stocks` or the main money desks. Full guide: [Thrift module](/docs/modules/thrift).
