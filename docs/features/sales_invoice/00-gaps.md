# Sales invoice — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| SI1 | doc_wrong | ACs were `[ ]` | Issue/return RPCs shipped | Tick ACs in `01-prd` that already match wholesale issue/return |
| SI2 | doc_wrong | Older docs may say status `posted` | Live document status is `issued` | Never resurrect `posted` |
| SI3 | ~~design~~ | Invoice = bill only; issue ≠ pay | ~~Issue fused with deliver~~ | **Done (2026-09):** merchant bill at ship; deliver books COD only |
| SI4 | ~~design~~ | `sell` / `total` = tenant sell only | ~~`recipient_price` aliased to `sell_price`~~ | **Done (2026-09):** `line_meta.resell_price_amount`; list RPC reads meta |
| SI5 | design | Cost is internal snapshot, not the bill | `unit_cost_price` on `sales_invoice_items`; print/UI can treat it as invoice data | `sales_invoice_item_costs`; hide on voucher |
| SI6 | design | Channel extras in `channel_meta` / `line_meta` | Header `cod_charge_amount`, `shipping_charge`, recipient columns, `fulfillment_status` on invoice | Meta + order for COD/parcel; charges table only for merchant-owed fees |
| SI7 | ~~not_built~~ | Target tables in `02-data-model` | ~~Missing columns/tables~~ | **Done (2026-09):** additive migration; old cost/COD columns kept until writers gone |
| SI8 | ~~design~~ | One dropship issue RPC, packing slip ≠ invoice | ~~Dual paths + delivered-only issue~~ | **Done (2026-09):** wrappers → `issue_dropship_tenant_b2b_invoice`; packing slip in `shop_order` |
| SI9 | design | Collect / remittance are receipts, not invoice issue | Invoice collect RPC vs dropship remittance RPCs | Same receipt path as [wallet 00-gaps](../wallet/00-gaps.md) WA4–WA8 |
