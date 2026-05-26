PC_JSON ?= ../web/public/uk/pc_data.json
PC_VENDOR ?= PC
PC_MARKET ?= GB

WTS_JSON ?= ../web/public/uk/wts_data.json
WTS_VENDOR ?= WTS
WTS_MARKET ?= GB

pc:
	python scripts/uk/export_pc_data.py
	python scripts/uk/normalize_pc_data.py --input "$(PC_JSON)" --no-backup
	python scripts/uk/remove_vat_from_names.py --input "$(PC_JSON)" --fields name --no-backup
	python scripts/uk/move_ml_to_end.py --input "$(PC_JSON)" --fields name --no-backup
	python scripts/uk/sync_pc_products_to_supabase.py --input "$(PC_JSON)" --vendor "$(PC_VENDOR)" --market "$(PC_MARKET)"

pc-csv:
	python scripts/uk/export_pc_csv.py

pc-normalize:
	python scripts/uk/normalize_pc_data.py --input "$(PC_JSON)"

pc-clean-names:
	python scripts/uk/remove_vat_from_names.py --input "$(PC_JSON)" --fields name
	python scripts/uk/move_ml_to_end.py --input "$(PC_JSON)" --fields name

pc-sync-db:
	python scripts/uk/sync_pc_products_to_supabase.py --input "$(PC_JSON)" --vendor "$(PC_VENDOR)" --market "$(PC_MARKET)"

wts:
	python scripts/uk/export_wts_data.py --skip-images
	python scripts/uk/normalize_pc_data.py --input "$(WTS_JSON)" --no-backup
	python scripts/uk/remove_vat_from_names.py --input "$(WTS_JSON)" --fields name --no-backup
	python scripts/uk/move_ml_to_end.py --input "$(WTS_JSON)" --fields name --no-backup
	python scripts/uk/sync_pc_products_to_supabase.py --input "$(WTS_JSON)" --vendor "$(WTS_VENDOR)" --market "$(WTS_MARKET)" --tenant-id 10 --vendor-id 4 --images-dir images/uk/wts_images --skip-image-upload

wts-scrape:
	python scripts/uk/export_wts_data.py --skip-images

wts-sync:
	python scripts/uk/sync_pc_products_to_supabase.py --input "$(WTS_JSON)" --vendor "$(WTS_VENDOR)" --market "$(WTS_MARKET)" --tenant-id 10 --vendor-id 4 --images-dir images/uk/wts_images --skip-image-upload
