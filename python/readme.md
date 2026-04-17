python3 -m venv .venv
source .venv/bin/activate

pip install -r requirements.txt

Set shared env values in `web/.env` (single env for web + python):

```env
PY_SUPABASE_STORAGE_BUCKET=product-images
PY_SUPABASE_STORAGE_PREFIX=uk/pc
SUPABASE_SECRET_KEY=your_supabase_secret_key
# Legacy fallback:
# SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
# Optional sync scope (defaults shown)
# PY_PRODUCTS_VENDOR_CODE=PC
# PY_PRODUCTS_MARKET_CODE=GB
# PY_PRODUCTS_TENANT_ID=
```

Run UK export:

```bash
python scripts/uk/export_pc_data.py
```

From repo root you can also run:

```bash
npm run python:pc
```

`npm run python:pc` now does all of this in sequence:
1. Export from Excel + upload images to Supabase Storage bucket
2. Normalize/clean product names in `web/public/uk/pc_data.json`
3. Sync into Supabase `products` with scope `vendor_code=PC`, `market_code=GB` by default
   - Match key: `(barcode, product_code)` inside that scope
   - If matched: update existing row(s)
   - If not matched: insert new row

Export brand and category lists from the generated PC JSON:

```bash
python scripts/uk/export_pc_taxonomy.py --input ../web/public/uk/pc_data.json
```

Excel columns expected (case-insensitive):

Required:
1. `product_code`
2. `barcode`
3. `case_size`
4. `name`
5. `price`
6. `image` (embedded image column index is provided when script prompts)

Optional:
1. `country_of_origin`
2. `brand`
3. `expire_date` (aliases: `expiry_date`, `expiration_date`, `exp_date`)

Notes:
1. `product_id` is generated as `barcode + '_' + product_code`.
2. Export always writes `expire_date`; missing values become `""`.
3. `export_pc_taxonomy.py` writes `web/public/uk/brands.json` and `web/public/uk/categories.json`.
