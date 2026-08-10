# Thrift Barcodes — Workflow

Part of [Thrift](../README.md). Overview: [../workflow.md](../workflow.md).

Schema: [schema.md](./schema.md)

---

## Workflow

1. Generate label pool (`AVAILABLE`).
2. Print / mark printed.
3. Register stock → barcode `USED`.
4. Stock delete → barcode released `AVAILABLE`.

**RPC / API:**
- [rpc/generate_thrift_barcodes.md](./rpc/generate_thrift_barcodes.md)
- [rpc/list_thrift_barcodes_paginated.md](./rpc/list_thrift_barcodes_paginated.md)
- [api/thrift_barcode_api.md](./api/thrift_barcode_api.md)
