# BrandWala Wholesale Quasar

BrandWala Wholesale Quasar is a Quasar-based business platform for managing wholesale and commerce operations in one place.

## What this project offers

The app brings together the core workflows needed to run a multi-role wholesale business:

- role-based login for superadmin, admin, staff, viewer, and customer access
- dashboards for different user types
- product, store, inventory, and market management
- invoices, orders, shipments, and billing workflows
- costing and product-based costing tools
- commerce and shop views for customer-facing access
- Supabase-backed data, authentication, and permissions

## Main areas

- `Platform` for superadmin administration
- `App` for internal business operations
- `Shop` for customer-side browsing and purchasing flows

## Tech stack

- Frontend: Quasar SPA
- Backend: Supabase
- Authentication: Google OAuth through Supabase
- Deployment: Cloudflare Pages for the frontend

## Project structure

- `web/` frontend application
- `supabase/` database migrations, local config, and generated types

## High-level auth model

The app uses scoped login flows and membership-based access control:

- `platform` for superadmin access
- `app` for admin, staff, and viewer access
- `shop` for customer access

Access is determined by email, role, active membership status, and tenant/customer group rules.

## Deployment notes

For Cloudflare Pages:

- root directory: `web`
- build command: `npm install && npm run build`
- build output directory: `dist/spa`

Common environment variables:

- `NODE_VERSION=22`
- `SKIP_DEPENDENCY_INSTALL=true`
- `VITE_SUPABASE_ANON_KEY`
- `VITE_SUPABASE_URL`
- `VITE_LOCAL_APP_URL`
- `VITE_PRODUCTION_APP_URL`

## Local development

Use the root `package.json` scripts to run and build the app.

- `npm run dev`
- `npm run build`
- `npm run lint`

If you need the detailed backend architecture, Supabase role model, or migration guidance, check the docs in `document/`.

## Database Optimization (Reclaiming Space)

If your database size grows due to expired product sync snapshots, you can optimize it by running the following SQL queries in the Supabase Dashboard SQL Editor:

```sql
-- 1. Delete all expired snapshots (older than 7 days)
DELETE FROM public.product_sync_snapshots 
WHERE expires_at < now();

-- 2. Immediately reclaim the disk space back to the OS
VACUUM FULL public.product_sync_snapshots;
```

Alternatively, you can execute the deletion using the Supabase CLI in your terminal:

```bash
# Delete all expired snapshots
npx supabase db query --linked "DELETE FROM public.product_sync_snapshots WHERE expires_at < now();"
```

> [!IMPORTANT]
> **Reclaiming space (VACUUM):** The Supabase CLI `db query` command wraps executions in a transaction block, which will cause `VACUUM FULL` to fail with `ERROR: 25001: VACUUM cannot run inside a transaction block`. Always run the `VACUUM FULL` query directly in the **Supabase Dashboard SQL Editor** instead of the CLI.


