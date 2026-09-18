# `supabase/schemas/` — current public schema

How-to: [doc/supabase-schema.md](../../doc/supabase-schema.md)

| File / folder | Status |
|---------------|--------|
| `_extensions.sql` | Live — extensions the dump does not emit |
| `public.sql` | Live — remaining public schema (unsplit modules) |
| `procurement/` | Live — shipments, stock, costing, vendors (`01_types.sql` … `04_rls.sql`) |
| `shop_order/` | Live — shops, carts, orders, dropship (`01_types.sql` … `04_rls.sql`) |
| `tenants/` `permissions/` `shop/` `sales_invoice/` `thrift/` `wallet/` `investor/` `global_reference/` `tag/` | Stubs — move objects here when you change that module; delete them from `public.sql` in the same PR |

Split one folder: [doc/supabase-schema.md](../../doc/supabase-schema.md). In Agent mode type `split schema tag` (or another domain).

`migrations/` is still what production runs. Edit here, then `pnpm run backend:schema:diff` / `supabase db diff -f …`.
