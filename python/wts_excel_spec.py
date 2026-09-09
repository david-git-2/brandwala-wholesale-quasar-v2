"""Required WTS Excel headers and how they map to products."""

import re

FORMULA_TEXT_RE = re.compile(
    r"^=|_xlfn\.|\b(?:XLOOKUP|VLOOKUP|HLOOKUP|INDEX|MATCH)\s*\(",
    re.IGNORECASE,
)


def sanitize_cell_text(value) -> str:
    """Return cell text; empty when missing or an unresolved Excel formula."""
    if value is None:
        return ""
    text = str(value).strip()
    if not text:
        return ""
    if FORMULA_TEXT_RE.search(text):
        return ""
    return text


REQUIRED_WTS_COLUMNS = [
    {
        "key": "product_code",
        "excel": "ProdCode",
        "db": "products.product_code",
        "aliases": ["prodcode", "product_code", "product code", "code"],
        "row_required": True,
        "note": "Must have a value on each row.",
    },
    {
        "key": "barcode",
        "excel": "Barcode",
        "db": "products.barcode",
        "aliases": ["barcode", "bar code", "ean"],
        "row_required": True,
        "note": "Must have a value on each row.",
    },
    {
        "key": "name",
        "excel": "Product Description",
        "db": "products.name",
        "aliases": ["product description", "description", "name", "product_name", "product name"],
        "row_required": True,
        "note": "Must have a value on each row.",
    },
    {
        "key": "price",
        "excel": "Each",
        "db": "products.list_price_amount",
        "aliases": ["each", "unit_price", "unit price", "piece_price", "piece price"],
        "note": "Unit price in GBP (`list_price_currency_id`).",
    },
    {
        "key": "case_size",
        "excel": "Pack",
        "db": "products.minimum_order_quantity",
        "aliases": ["pack", "case_size", "case size", "inner_case", "inner case"],
        "note": "MOQ / units per outer case.",
    },
    {
        "key": "available_units",
        "excel": "Available",
        "db": "products.available_units",
        "aliases": ["available", "available_units", "available units", "stock"],
        "note": "Stock count; drives availability scope on sync.",
    },
]

OPTIONAL_WTS_COLUMNS = [
    {
        "key": "pack_price",
        "excel": "Price",
        "aliases": ["price", "pack_price", "pack price", "case_price", "case price"],
        "note": "Pack/case price (JSON only; not synced).",
    },
    {
        "key": "outer_barcode",
        "excel": "Outer Barcode",
        "aliases": ["outer barcode", "outer_barcode", "carton barcode"],
        "note": "JSON only; not synced.",
    },
    {
        "key": "outer_per_plt",
        "excel": "Pallet Qty",
        "aliases": ["pallet qty", "pallet_qty", "outer per plt", "outer_per_plt"],
        "note": "JSON only; not synced.",
    },
    {
        "key": "layer_qty",
        "excel": "Layer Qty",
        "aliases": ["layer qty", "layer_qty"],
        "note": "JSON only; not synced.",
    },
]


def required_field_candidates() -> dict[str, list[str]]:
    return {col["key"]: list(col["aliases"]) for col in REQUIRED_WTS_COLUMNS}


def optional_field_candidates() -> dict[str, list[str]]:
    return {col["key"]: list(col["aliases"]) for col in OPTIONAL_WTS_COLUMNS}


def all_field_candidates() -> dict[str, list[str]]:
    out = required_field_candidates()
    out.update(optional_field_candidates())
    return out
