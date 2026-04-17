
PC_JSON ?= ../web/public/uk/pc_data.json

pc:
	python scripts/uk/export_pc_data.py
	python scripts/uk/normalize_pc_data.py --input "$(PC_JSON)" --no-backup
	python scripts/uk/remove_vat_from_names.py --input "$(PC_JSON)" --fields name --no-backup
	python scripts/uk/move_ml_to_end.py --input "$(PC_JSON)" --fields name --no-backup

pc-csv:
	python scripts/uk/export_pc_csv.py

pc-normalize:
	python scripts/uk/normalize_pc_data.py --input "$(PC_JSON)"

pc-clean-names:
	python scripts/uk/remove_vat_from_names.py --input "$(PC_JSON)" --fields name
	python scripts/uk/move_ml_to_end.py --input "$(PC_JSON)" --fields name
