# Legacy & Confusing Parts Guide (Junior Developer Survival Guide)

This project has evolved through multiple major rewrites (multi-tenant hierarchy changes, a new money/billing kernel, and V1 → V2 feature migrations). Because old and new code still coexist, implementing a "simple" flow often feels harder than it should.

This guide explains **what is confusing, why it looks like that, and what you should use instead**.

---

## 1. Database Schema & Migrations Maze

### Why it's confusing
- **`supabase/schemas/public.sql` is ~2.6 MB** (a monolithic dump of the `public` schema, currently being split into domain folders).
- **Partially split schemas:** `supabase/config.toml` (`schema_paths`) currently loads `_extensions.sql`, `public.sql`, `thrift/*`, `costing/*`, `money_kernel_v2/*`, and `reporting/01_customer_report_rpcs.sql`. Other folders like `supabase/schemas/bills_pays/` are **not** listed in `schema_paths`.
- **340+ migrations:** `supabase/migrations/` has over 340 files (including future-dated timestamps like `20261124...` and `20270918...` used as ordered sequence numbers), with many small hotfix/compat migrations layered on top of each other.

### Rule of thumb
- Check `supabase/config.toml` (`schema_paths`) to know which declarative schema files are actually active.
- For `bills_pays` SQL, read `supabase/schemas/bills_pays/README.md` before editing—some files are archive references while `05_money_spine.sql` and `money_kernel_v2/` are active sources.

---

## Quick Checklist Before Starting a New Flow

1. **Check the route first:** Look in `moduleRegistry.ts` to make sure you're working in the active module.
2. **Use `tenant_id`:** Don't add new `parent_tenant_id` or company-hierarchy references.
3. **Use the money kernel:** For anything touching bills, payments, or cashbook, target `bills_pays` + `money_kernel_v2` (`rpc_*` via `moneyKernelRepository.ts`, which uses `supabase as any` for untyped RPCs).
4. **Verify currency context:** Explicitly track whether a field is in **books currency (BDT)**, **purchase currency**, or **settlement currency**.
