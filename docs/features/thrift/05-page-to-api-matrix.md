# Thrift Vertical — Page-to-API Matrix

Mapping of all thrift inventory screens, garment registers, barcode printers, POS desks, and risk evaluators to their corresponding Supabase RPCs, database operations, and TanStack Vue Query cache keys.

---

## 📊 Interaction & Endpoint Matrix

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation / Optimistic Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **`ThriftStockPage`** | Mount / Filter by Category | `useThriftStocksQuery` | `RPC: list_thrift_stocks_paginated` | Cached on `thriftQueryKeys.stocks` (`staleTime: 30s`) |
| **`ThriftStockRegisterDialog`** | Register Single Garment | `useRegisterThriftStockMutation` | `RPC: register_thrift_stock_from_app` | Appends item, invalidates stock list |
| **`ThriftBarcodePage`** | Generate Serial Barcode Batch | `useGenerateBarcodesMutation`| `RPC: generate_thrift_barcodes` | Refetches `thriftQueryKeys.barcodes` |
| **`ThriftCreateSalesInvoicePage`**| Customer Phone Input (Blur)| `useCustomerRiskQuery` | `RPC: get_thrift_customer_sales_risk` | Cached on `thriftQueryKeys.customerRisk(phone)` |
| **`ThriftCreateSalesInvoicePage`**| Complete Sale (Scanner POS)| `useCreateThriftInvoiceMutation` | `RPC: create_thrift_sales_invoice` | Commits sold inventory; invalidates stock & sales |
| **`ThriftSalesReturnsPage`** | Submit Customer Return | `useThriftReturnMutation` | `RPC: create_thrift_sales_return` | Restores stock to `in_stock` or `damaged` |
