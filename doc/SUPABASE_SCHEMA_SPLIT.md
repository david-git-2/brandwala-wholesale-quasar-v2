# Split one schema module

You do not write a long prompt. In Agent mode, type one of:

```
split schema tag
split schema procurement
split next schema module
```

The agent follows `.agents/skills/schema-split/SKILL.md`. How-to for daily DDL: [SUPABASE_SCHEMA.md](SUPABASE_SCHEMA.md).

## Status

One row per session. Move-only (no new migration unless you also asked for a behavior change).

| Domain | Folder | Status |
|--------|--------|--------|
| tag | `supabase/schemas/tag/` | Stub |
| global_reference | `supabase/schemas/global_reference/` | Stub |
| tenants | `supabase/schemas/tenants/` | Stub |
| permissions | `supabase/schemas/permissions/` | Stub |
| investor | `supabase/schemas/investor/` | Stub |
| wallet | `supabase/schemas/wallet/` | Stub |
| thrift | `supabase/schemas/thrift/` | Stub |
| sales_invoice | `supabase/schemas/sales_invoice/` | Split |
| shop | `supabase/schemas/shop/` | Stub |
| shop_order | `supabase/schemas/shop_order/` | Stub |
| procurement | `supabase/schemas/procurement/` | Split |

Prefer small first (`tag`, `global_reference`). `split next` = first **Stub** row.

## Done means

Objects for that domain live under its folder. The same objects are **gone** from `supabase/schemas/public.sql`. `pnpm run backend:schema:diff` does not propose `DROP` of other modules.
