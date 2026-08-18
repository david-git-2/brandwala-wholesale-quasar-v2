---
name: schema-split
description: >-
  Move one domain’s current SQL out of supabase/schemas/public.sql into
  supabase/schemas/<domain>/. Use when the user says split schema, split
  module, schema split, split next schema module, or names a schemas/
  domain folder to extract (tag, thrift, procurement, wallet, shop, …).
---

Read **[doc/SUPABASE_SCHEMA_SPLIT.md](../../../doc/SUPABASE_SCHEMA_SPLIT.md)** and **[doc/SUPABASE_SCHEMA.md](../../../doc/SUPABASE_SCHEMA.md)** first.

## Which module

1. If the user named a domain, use that.
2. Else use the first **Stub** row in `doc/SUPABASE_SCHEMA_SPLIT.md`.
3. **One domain per session.** Stop when that row is updated.

Name prefixes (grep `supabase/schemas/public.sql`; also read that domain’s `doc/**/schema.md` if it exists):

| Domain | Typical objects |
|--------|-----------------|
| tag | `tag_categories`, `tags`, tag RPCs |
| global_reference | currencies, markets, payment methods, units, cargo companies |
| tenants | `tenants`, `memberships`, tenant RPCs |
| permissions | modules, grants, `has_module_action`, role RPCs |
| investor | `investor_*` |
| wallet | `universal_wallet_*`, wallet RPCs |
| thrift | `thrift_*` |
| sales_invoice | `global_invoices`, invoice RPCs |
| shop | `shops`, listings, shop settings RPCs |
| shop_order | `shop_orders`, `shop_cart`, shop-order RPCs |
| procurement | `shipments`, `shipment_*`, `global_stocks`, costing |

## Do

1. Find `CREATE` for tables, types, functions, views, triggers, indexes, policies for **this domain only**.
2. Write them under `supabase/schemas/<domain>/` (`tables.sql`, `rpcs.sql`, `rls.sql` as needed).
3. **Delete the same objects from `public.sql` in the same change.** No duplicates.
4. Keep `_extensions.sql`. Do not dump into `supabase/.dumps/`.
5. Run `pnpm run backend:schema:diff`. Allowed leftover: grant/`OWNER TO`/CHECK recast noise already known from first dump. **Not allowed:** `DROP` of other modules’ tables or functions — that means you deleted too much or left a partial schema. Fix and re-diff.
6. Move-only: **do not** `db diff -f` / do not add a migration / do not `db push`.
7. Mark the domain **Split** in `doc/SUPABASE_SCHEMA_SPLIT.md`.

## Do not

- Split a second domain in the same session
- Edit old files in `supabase/migrations/`
- Touch production
- Invent objects that are not in `public.sql`

## If the user also wants a behavior change

After the split is clean: edit the **new** live file (not a hand `CREATE OR REPLACE` migration), `backend:schema:diff`, then `supabase db diff -f short_name`, strip grant/`OWNER` noise, `backend:reset`. Still no production push unless they asked.
