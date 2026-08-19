"""Required PC Excel headers and how they map to products."""

REQUIRED_PC_COLUMNS = [
    {
        "key": "available_units",
        "excel": "AVAILABLE UNITS",
        "db": "products.available_units",
        "aliases": ["available_units", "available units"],
    },
    {
        "key": "inner_case",
        "excel": "INNER CASE",
        "db": "products.minimum_order_quantity",
        "aliases": ["inner_case", "inner case"],
        "note": "Case size / MOQ. Always INNER CASE.",
    },
    {
        "key": "name",
        "excel": "DESCRIPTION",
        "db": "products.name",
        "aliases": ["name", "description", "product_name", "product name"],
        "row_required": True,
        "note": "Must have a value on each row.",
    },
    {
        "key": "product_code",
        "excel": "PRODUCT CODE",
        "db": "products.product_code",
        "aliases": ["product_code", "product code", "code"],
        "row_required": True,
        "note": "Must have a value on each row.",
    },
    {
        "key": "expire_date",
        "excel": "EXPIRY DATE",
        "db": "products.expire_date",
        "aliases": ["expire_date", "expiry_date", "expiry date", "expiration_date", "exp_date"],
    },
    {
        "key": "price",
        "excel": "PIECE PRICE £",
        "db": "products.list_price_amount",
        "aliases": [
            "price",
            "piece_price",
            "piece price",
            "piece_price_gbp",
            "unit_price",
            "unit price",
        ],
        "note": "Currency is GBP (`list_price_currency_id`).",
    },
    {
        "key": "barcode",
        "excel": "BARCODE",
        "db": "products.barcode",
        "aliases": ["barcode", "bar code", "ean"],
    },
    {
        "key": "country_of_origin",
        "excel": "COUNTRY OF ORIGIN",
        "db": "products.country_of_origin",
        "aliases": ["country_of_origin", "country of origin", "country"],
    },
    {
        "key": "languages",
        "excel": "LANGUAGES",
        "db": "products.languages",
        "aliases": ["languages", "language"],
    },
    {
        "key": "batch_code_manufacture_date",
        "excel": "BATCH CODE / MANUFACTURE DATE",
        "db": "products.batch_code_manufacture_date",
        "aliases": [
            "batch_code_manufacture_date",
            "batch code / manufacture date",
            "batch code manufacture date",
            "batch_code",
            "manufacture_date",
        ],
    },
    {
        "key": "image",
        "excel": "IMAGE",
        "db": "products.image_url",
        "aliases": ["image", "image url", "photo"],
        "note": "Embedded pictures under this header.",
    },
    {
        "key": "brand",
        "excel": "BRAND",
        "db": "products.brand",
        "aliases": ["brand"],
    },
    {
        "key": "hazardous",
        "excel": "HAZARDOUS",
        "db": "products.hazardous",
        "aliases": ["hazardous"],
        "note": "YES / Y / TRUE / 1 → drop the row.",
    },
    {
        "key": "category",
        "excel": "CATEGORY",
        "db": "products.category",
        "aliases": ["category"],
    },
]


def required_field_candidates() -> dict[str, list[str]]:
    return {col["key"]: list(col["aliases"]) for col in REQUIRED_PC_COLUMNS}
