# Thrift stock hold (`RESERVED`)

Online / Facebook holds remove a unit from open sell without an invoice.

| Action | Result |
| :--- | :--- |
| **Hold** | `AVAILABLE` → `RESERVED`; requires customer phone |
| **Open POS search** | `AVAILABLE` only |
| **POS + matching phone** | Also returns that phone’s `RESERVED`; convert allowed |
| **Sell other desk** | Reject unless invoice phone matches hold |
| **Release** | `RESERVED` → `AVAILABLE` |
| **Expiry** | `hold_expires_at` advisory only (v1) |

RPCs: [rpc/hold_thrift_stock.md](./rpc/hold_thrift_stock.md) · [rpc/release_thrift_stock_hold.md](./rpc/release_thrift_stock_hold.md)  
Sale convert: [../sales/rpc/create_thrift_sales_invoice.md](../sales/rpc/create_thrift_sales_invoice.md)
