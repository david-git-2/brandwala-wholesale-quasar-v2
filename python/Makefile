PC_JSON ?= data/uk/out/pc_data.json
PC_VENDOR ?= PC
PC_MARKET ?= GB
PC_EXPORT_FLAGS ?=
PC_SYNC_FLAGS ?= --tenant-id 15 --vendor-id 3

WTS_JSON ?= data/uk/out/wts_data.json
WTS_VENDOR ?= WTS
WTS_MARKET ?= GB
WTS_EXPORT_FLAGS ?=
# Books scope --tenant-id 15; child inserted-by --inserted-by-tenant-id 10.
WTS_SYNC_FLAGS ?= --vendor-id 4 --tenant-id 15 --inserted-by-tenant-id 10

pc:
	cd .. && pnpm env:prod
	python scripts/uk/export_pc_data.py $(PC_EXPORT_FLAGS)
	python scripts/uk/normalize_pc_data.py --input "$(PC_JSON)" --no-backup
	python scripts/uk/remove_vat_from_names.py --input "$(PC_JSON)" --fields name --no-backup
	python scripts/uk/move_ml_to_end.py --input "$(PC_JSON)" --fields name --no-backup
	CATALOG_REFRESH_SOURCE=pc python scripts/uk/sync_pc_products_to_supabase.py --input "$(PC_JSON)" --vendor "$(PC_VENDOR)" --market "$(PC_MARKET)" --catalog-source pc $(PC_SYNC_FLAGS)

pc-csv:
	python scripts/uk/export_pc_csv.py

pc-normalize:
	python scripts/uk/normalize_pc_data.py --input "$(PC_JSON)"

pc-clean-names:
	python scripts/uk/remove_vat_from_names.py --input "$(PC_JSON)" --fields name
	python scripts/uk/move_ml_to_end.py --input "$(PC_JSON)" --fields name

pc-sync-db:
	cd .. && pnpm env:prod
	CATALOG_REFRESH_SOURCE=pc python scripts/uk/sync_pc_products_to_supabase.py --input "$(PC_JSON)" --vendor "$(PC_VENDOR)" --market "$(PC_MARKET)" --catalog-source pc $(PC_SYNC_FLAGS)

pc-sync-dry:
	cd .. && pnpm env:local
	CATALOG_REFRESH_SOURCE=pc python3 scripts/uk/sync_pc_products_to_supabase.py --input "$(PC_JSON)" --vendor "$(PC_VENDOR)" --market "$(PC_MARKET)" --catalog-source pc $(PC_SYNC_FLAGS) --dry-run

wts:
	python scripts/uk/export_wts_data.py --skip-images --tenant-id 15
	python scripts/uk/normalize_pc_data.py --input "$(WTS_JSON)" --no-backup
	python scripts/uk/remove_vat_from_names.py --input "$(WTS_JSON)" --fields name --no-backup
	python scripts/uk/move_ml_to_end.py --input "$(WTS_JSON)" --fields name --no-backup
	CATALOG_REFRESH_SOURCE=wts python scripts/uk/sync_wts_products_to_supabase.py --input "$(WTS_JSON)" --market "$(WTS_MARKET)" --catalog-source wts $(WTS_SYNC_FLAGS)

wts-scrape:
	python scripts/uk/export_wts_data.py --skip-images --tenant-id 15

wts-sync:
	CATALOG_REFRESH_SOURCE=wts python scripts/uk/sync_wts_products_to_supabase.py --input "$(WTS_JSON)" --market "$(WTS_MARKET)" --catalog-source wts $(WTS_SYNC_FLAGS)

wts-check-duplicates:
	python scripts/uk/check_wts_duplicate_barcodes.py --vendor-id 4 --market "$(WTS_MARKET)" --tenant-id 15

wts-excel:
	python scripts/uk/export_wts_excel.py $(WTS_EXPORT_FLAGS)
	python scripts/uk/normalize_wts_data.py --input "$(WTS_JSON)" --no-backup
	python scripts/uk/remove_vat_from_names.py --input "$(WTS_JSON)" --fields name --no-backup
	python scripts/uk/move_ml_to_end.py --input "$(WTS_JSON)" --fields name --no-backup
	CATALOG_REFRESH_SOURCE=wts_excel python scripts/uk/sync_wts_products_to_supabase.py --input "$(WTS_JSON)" --market "$(WTS_MARKET)" --catalog-source wts_excel $(WTS_SYNC_FLAGS)

KOBA_RETAIL_JSON ?= data/uk/out/koba_retail_data.json
KOBA_RETAIL_VENDOR ?= KOBA_RETAIL
KOBA_RETAIL_MARKET ?= GB

koba-retail:
	python scripts/uk/export_koba_retail_data.py --tenant-id 10

koba-retail-scrape:
	python scripts/uk/export_koba_retail_data.py --tenant-id 10

koba-retail-sync:
	CATALOG_REFRESH_SOURCE=koba_retail python scripts/uk/sync_pc_products_to_supabase.py --input "$(KOBA_RETAIL_JSON)" --vendor "$(KOBA_RETAIL_VENDOR)" --market "$(KOBA_RETAIL_MARKET)" --tenant-id 10 --catalog-source koba_retail --skip-image-upload

KOBA_WHOLESALE_JSON ?= data/uk/out/koba_wholesale_data.json
KOBA_WHOLESALE_VENDOR ?= KOBA_WHOLESALE
KOBA_WHOLESALE_MARKET ?= GB

koba-wholesale:
	python scripts/uk/export_koba_wholesale_data.py --tenant-id 10

koba-wholesale-scrape:
	python scripts/uk/export_koba_wholesale_data.py --tenant-id 10

koba-wholesale-sync:
	CATALOG_REFRESH_SOURCE=koba_wholesale python scripts/uk/sync_pc_products_to_supabase.py --input "$(KOBA_WHOLESALE_JSON)" --vendor "$(KOBA_WHOLESALE_VENDOR)" --market "$(KOBA_WHOLESALE_MARKET)" --tenant-id 10 --catalog-source koba_wholesale --skip-image-upload

ELF_JSON ?= data/uk/out/elf_data.json
ELF_VENDOR ?= ELF
ELF_MARKET ?= GB

# Full pipeline: scrape → remap existing keys → sync (update/insert)
# Locked scope: vendor_id=5, inserted_by_tenant_id=10, books tenant_id=15
elf:
	python scripts/uk/export_elf_data.py --tenant-id 15
	python scripts/uk/remap_elf_product_keys.py --tenant-id 15 --apply
	CATALOG_REFRESH_SOURCE=elf python scripts/uk/sync_pc_products_to_supabase.py \
		--input "$(ELF_JSON)" \
		--vendor "$(ELF_VENDOR)" \
		--market "$(ELF_MARKET)" \
		--tenant-id 15 \
		--inserted-by-tenant-id 10 \
		--vendor-id 5 \
		--catalog-source elf \
		--skip-image-upload

elf-scrape:
	python scripts/uk/export_elf_data.py --tenant-id 15

elf-remap-keys:
	python scripts/uk/remap_elf_product_keys.py --tenant-id 15

elf-remap-keys-apply:
	python scripts/uk/remap_elf_product_keys.py --tenant-id 15 --apply

elf-sync:
	CATALOG_REFRESH_SOURCE=elf python scripts/uk/sync_pc_products_to_supabase.py \
		--input "$(ELF_JSON)" \
		--vendor "$(ELF_VENDOR)" \
		--market "$(ELF_MARKET)" \
		--tenant-id 15 \
		--inserted-by-tenant-id 10 \
		--vendor-id 5 \
		--catalog-source elf \
		--skip-image-upload
