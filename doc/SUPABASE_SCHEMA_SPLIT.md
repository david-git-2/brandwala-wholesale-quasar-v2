# Supabase schema split tracker

Live SQL lives in `supabase/schemas/`. Move one domain per PR; delete moved objects from `public.sql` in the same change. Run `pnpm run backend:schema:diff` before merge.

| Domain | Folder | Status | Notes |
| :--- | :--- | :--- | :--- |
| procurement | `procurement/` | **Split** | types, tables, rpcs, rls |
| shop_order | `shop_order/` | **Split** | types, tables, rpcs, rls — wired in `config.toml` |
| sales_invoice | `sales_invoice/` | Partial | files exist; not yet wired in `config.toml` |
| shop | `shop/` | Stub | Use `shop_order/` (same module) |
| tenants | `tenants/` | Stub | |
| permissions | `permissions/` | Stub | |
| wallet | `wallet/` | Stub | |
| thrift | `thrift/` | Stub | |
| investor | `investor/` | Stub | |
| global_reference | `global_reference/` | Stub | |
| tag | `tag/` | Stub | |
