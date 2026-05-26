# TradeFlow BD Automation & Script Commands Guide

This document lists and explains all commands available in `package.json` for frontend development, catalog scraping/syncing, and backend Supabase migration tasks.

---

## 1. Frontend Development & Build

These commands are used to develop, build, and check the code style of the Quasar/Vite frontend application:

*   **`npm run dev`**
    *   **Action**: `npm --prefix web run dev`
    *   **Purpose**: Launches the Quasar local development server. Features hot-module-replacement (HMR).
*   **`npm run build`**
    *   **Action**: `npm --prefix web run build`
    *   **Purpose**: Compiles and bundles the frontend code for production deployment.
*   **`npm run lint`**
    *   **Action**: `npm --prefix web run lint`
    *   **Purpose**: Runs ESLint checks to enforce frontend coding standards.

---

## 2. Scraping & Data Processing Scripts

These python-based tasks are used to fetch, normalize, and clean wholesale product catalogs:

*   **`npm run python:scrape:pc`**
    *   **Action**: Runs `python3 python/scripts/uk/export_pricecheck_scraper.py` inside the virtual environment.
    *   **Purpose**: Logs in to the online PriceCheck portal using Playwright, crawls all active categories and pages, parses product cards (including barcodes, SKU codes, available quantities, and prices), and outputs the results to `web/public/uk/pc_scraped_data.json`.
*   **`npm run python:normalize:pc`**
    *   **Action**: `python3 python/scripts/uk/normalize_pc_data.py --input web/public/uk/pc_data.json`
    *   **Purpose**: Normalizes the static PriceCheck catalog JSON file. Computes minimum order quantities based on case sizes and filters out hazardous products.
*   **`npm run python:clean:vat-names`**
    *   **Action**: `python3 python/scripts/uk/remove_vat_from_names.py --input web/public/uk/pc_data.json`
    *   **Purpose**: Cleans product names in the PriceCheck JSON file by removing text indicating VAT inclusion/exclusion.
*   **`npm run python:clean:ml-names`**
    *   **Action**: `python3 python/scripts/uk/move_ml_to_end.py --input web/public/uk/pc_data.json --fields name`
    *   **Purpose**: Cleans product names in the PriceCheck JSON file by shifting unit size details (like "100ml", "400g") to the end of the text string for visual consistency.
*   **`npm run python:taxonomy:pc`**
    *   **Action**: `python3 python/scripts/uk/export_pc_taxonomy.py --input web/public/uk/pc_data.json`
    *   **Purpose**: Extracts category hierarchy and taxonomies from the PriceCheck JSON file.
*   **`npm run python:pc`**
    *   **Action**: `bash scripts/run-python-pc.sh`
    *   **Purpose**: Runs pipeline tasks for local Excel sheet processing of static PriceCheck data.
*   **`npm run python:wts`**
    *   **Action**: `bash scripts/run-python-wts.sh`
    *   **Purpose**: Runs pipeline tasks for local Excel sheet processing of Wholesale Trading Supplies data.

---

## 3. Database Synchronization Scripts

These scripts push prepared JSON catalogs to the Supabase backend tables:

*   **`npm run python:sync:scraped-pc`**
    *   **Action**: Runs `python3 python/scripts/uk/sync_scraped_pc_to_supabase.py` inside the virtual environment.
    *   **Purpose**: Connects to the Supabase database. Automatically populates `product_brands` and `product_categories` lookup tables. Marks existing items in scope as unavailable, then syncs the newly scraped products (applying PATCH updates for existing products and bulk inserts for new ones).
*   **`npm run python:sync:pc`**
    *   **Action**: `python3 python/scripts/uk/sync_pc_products_to_supabase.py --input web/public/uk/pc_data.json --vendor PC --market GB`
    *   **Purpose**: Synchronizes the static PriceCheck catalog from `pc_data.json` into Supabase.
*   **`npm run python:sync:wts`**
    *   **Action**: `python3 python/scripts/uk/sync_pc_products_to_supabase.py --input web/public/uk/wts_data.json --vendor WTS --market GB --tenant-id 10 --vendor-id 4 --images-dir python/images/uk/wts_images --skip-image-upload`
    *   **Purpose**: Synchronizes the WTS catalog from `wts_data.json` into Supabase for Tenant 10 / Vendor 4.
*   **`npm run python:koba-retail`**
    *   **Action**: `bash scripts/run-python-koba-retail.sh`
    *   **Purpose**: Pushes Koba retail data sync updates to the backend.
*   **`npm run python:koba-wholesale`**
    *   **Action**: `bash scripts/run-python-koba-wholesale.sh`
    *   **Purpose**: Pushes Koba wholesale data sync updates to the backend.

---

## 4. Backend Deployment & Supabase Tasks

These commands manage database linkage, SQL schema migrations, and TypeScript type generation:

*   **`npm run backend:init`**
    *   **Action**: `npx supabase init`
    *   **Purpose**: Initializes a new Supabase local environment.
*   **`npm run backend:login`**
    *   **Action**: `npx supabase login`
    *   **Purpose**: Authenticates your Supabase developer account via CLI.
*   **`npm run backend:link`**
    *   **Action**: `npx supabase link --project-ref "$SUPABASE_PROJECT_REF"`
    *   **Purpose**: Links the local repository to your remote Supabase instance.
*   **`npm run backend:new-migration`**
    *   **Action**: `npx supabase migration new`
    *   **Purpose**: Scaffolds a new SQL migration file under `supabase/migrations/`.
*   **`npm run backend:push`**
    *   **Action**: `npx supabase db push --linked`
    *   **Purpose**: Pushes any pending local schema migrations to the linked remote database.
*   **`npm run backend:push:all`**
    *   **Action**: `npx supabase db push --linked --include-all`
    *   **Purpose**: Pushes all migrations, including historic or schema-altering configurations, to the linked remote database.
*   **`npm run backend:types`**
    *   **Action**: Generates TypeScript typings matching the remote database schema.
    *   **Purpose**: Writes types to `web/src/types/supabase.ts` for frontend TypeScript safety.
*   **`npm run deploy:backend`**
    *   **Action**: `npm run backend:push && npm run backend:types`
    *   **Purpose**: Pushes pending database migrations and regenerates the TypeScript types in a single command.
*   **`npm run backend:all`**
    *   **Action**: `npm run backend:push:all && npm run backend:types`
    *   **Purpose**: Full backend synchronization: pushes all migrations and regenerates types.
*   **`npm run backend:link:push:types`**
    *   **Action**: Performs linking, migration pushes, and type generation in sequence.
    *   **Purpose**: Resets or links a developer's workspace and updates database typings.

---

## 5. Deployment

*   **`npm run deploy:frontend`**
    *   **Action**: `bash scripts/deploy-frontend.sh`
    *   **Purpose**: Uploads and deploys the built frontend code to the hosting environment.
