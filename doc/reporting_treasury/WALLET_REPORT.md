# Wallet liability report (report 6)

Store credit owed to customers: issued in period, applied on invoices, and live outstanding balance.

**RPC:** `get_tenant_wallet_liability_report`  
**Route:** `/:tenantSlug?/app/finance/reports/wallet`

Outstanding is always current. Issued/applied respect the date filter. Row click opens staff wallet detail for that customer.
