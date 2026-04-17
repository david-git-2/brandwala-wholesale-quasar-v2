python3 -m venv .venv
source .venv/bin/activate

pip install -r requirements.txt

Set root `.env` values (at `/Users/david/Desktop/projects/group/brand-wala-wholesale/.env`):

```env
PY_GOOGLE_DRIVE_FOLDER_ID=your_google_drive_folder_id
PY_GOOGLE_OAUTH_CLIENT_JSON=python/credentials/oauth_client.json
PY_GOOGLE_TOKEN_JSON=python/credentials/token.json
```

Run UK export:

```bash
python scripts/uk/export_pc_data.py
```

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
