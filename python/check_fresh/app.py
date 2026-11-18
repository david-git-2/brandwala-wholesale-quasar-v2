from __future__ import annotations

import calendar
import re
from collections.abc import Callable
from dataclasses import dataclass
from datetime import date, datetime
from io import BytesIO
from pathlib import Path

import openpyxl
import streamlit as st
from openpyxl.formatting.rule import FormulaRule
from openpyxl.styles import Font
from openpyxl.utils import get_column_letter

from lookup import (
    BATCH_ALIASES,
    NAME_ALIASES,
    DecodeCache,
    load_brand_map,
    normalize_header,
    resolve_slug,
)

DEFAULT_HEADER_ROW = 1
MFG_LAST_COL = 16  # column P
MFG_HEADER_ALIASES = frozenset(
    {"manufacturing_date", "manufacture_date", "mfg", "production_date", "made"}
)


@dataclass
class InputRow:
    excel_row: int
    name: str
    batch: str


@dataclass
class SheetPreview:
    rows: list[InputRow]
    columns: list[tuple[int, str]]
    name_col: int
    batch_col: int


def read_header_map(ws, header_row: int) -> dict[str, int]:
    row = next(ws.iter_rows(min_row=header_row, max_row=header_row), None)
    if row is None:
        return {}
    mapping: dict[str, int] = {}
    for col_idx, cell in enumerate(row, start=1):
        if cell.value is None:
            continue
        key = normalize_header(str(cell.value))
        if key:
            mapping[key] = col_idx
    return mapping


def pick_column(mapping: dict[str, int], aliases: frozenset[str]) -> int | None:
    for alias in aliases:
        norm = normalize_header(alias)
        if norm in mapping:
            return mapping[norm]
    return None


def column_label(col: int, header: str) -> str:
    letter = get_column_letter(col)
    title = header.strip() if header else "(empty)"
    return f"{letter} — {title}"


def read_sheet_preview(file_bytes: bytes, header_row: int) -> SheetPreview:
    wb = openpyxl.load_workbook(BytesIO(file_bytes), data_only=True)
    try:
        ws = wb[wb.sheetnames[0]]
        col_map = read_header_map(ws, header_row)
        name_col = pick_column(col_map, NAME_ALIASES)
        batch_col = pick_column(col_map, BATCH_ALIASES)
        if not name_col or not batch_col:
            missing = []
            if not name_col:
                missing.append("name (or product / description)")
            if not batch_col:
                missing.append("batch (or batch code)")
            raise ValueError("Missing column(s): " + ", ".join(missing))

        header_text: dict[int, str] = {}
        header = next(ws.iter_rows(min_row=header_row, max_row=header_row), None)
        if header:
            for col_idx, cell in enumerate(header, start=1):
                if cell.value is None or col_idx > MFG_LAST_COL:
                    continue
                text = str(cell.value).strip()
                if text:
                    header_text[col_idx] = text

        columns = [
            (col, column_label(col, header_text.get(col, "")))
            for col in range(1, MFG_LAST_COL + 1)
        ]

        rows: list[InputRow] = []
        for excel_row in range(header_row + 1, (ws.max_row or header_row) + 1):
            name_val = ws.cell(excel_row, name_col).value
            batch_val = ws.cell(excel_row, batch_col).value
            name = "" if name_val is None else str(name_val).strip()
            batch = "" if batch_val is None else str(batch_val).strip()
            if not name and not batch:
                continue
            rows.append(InputRow(excel_row=excel_row, name=name, batch=batch))

        return SheetPreview(rows=rows, columns=columns, name_col=name_col, batch_col=batch_col)
    finally:
        wb.close()


def default_column(columns: list[tuple[int, str]], aliases: frozenset[str], fallback: int) -> int:
    for col, label in columns:
        title = label.split("—", 1)[-1].strip()
        if title != "(empty)" and normalize_header(title) in aliases:
            return col
    return fallback


def add_months(value: date, months: int) -> date:
    month_index = value.month - 1 + months
    year = value.year + month_index // 12
    month = month_index % 12 + 1
    day = min(value.day, calendar.monthrange(year, month)[1])
    return date(year, month, day)


def format_dmy(value: date) -> str:
    return value.strftime("%d/%m/%Y")


def expire_formula(mfg_letter: str, row: int) -> str:
    cell = f"{mfg_letter}{row}"
    return f'=IF({cell}="","",EDATE({cell},36))'


def remaining_formula(mfg_letter: str, expire_letter: str, row: int) -> str:
    made = f"{mfg_letter}{row}"
    expires = f"{expire_letter}{row}"
    msg = "If more than 18 months then will be accepted"
    return (
        f'=IF({made}="","{msg}",IF({expires}<TODAY(),"expired",'
        f'DATEDIF(TODAY(),{expires},"m")&" months "&DATEDIF(TODAY(),{expires},"md")&" days"))'
    )


def ensure_header(ws, header_row: int, col: int, title: str) -> None:
    cell = ws.cell(header_row, col)
    if cell.value is None or str(cell.value).strip() == "":
        cell.value = title


def build_output_workbook(
    file_bytes: bytes,
    rows: list[InputRow],
    header_row: int,
    mfg_col: int,
    expire_col: int,
    remaining_col: int,
    cache: DecodeCache,
    on_item: Callable[[int, int, str], None] | None = None,
) -> tuple[bytes, list[str]]:
    brand_map = load_brand_map()
    wb = openpyxl.load_workbook(BytesIO(file_bytes))
    ws = wb[wb.sheetnames[0]]
    mfg_letter = get_column_letter(mfg_col)
    expire_letter = get_column_letter(expire_col)
    ensure_header(ws, header_row, mfg_col, "manufacturing date")
    ensure_header(ws, header_row, expire_col, "expire date")
    ensure_header(ws, header_row, remaining_col, "remaining")

    planned: list[tuple[InputRow, str]] = []
    pairs: list[tuple[str, str]] = []
    for item in rows:
        batch = item.batch.strip()
        if not batch or batch == "-" or not item.name.strip():
            planned.append((item, ""))
            continue
        slug = resolve_slug(item.name, brand_map)
        planned.append((item, slug))
        if slug:
            pairs.append((slug, batch))

    total = len(planned)
    log_lines: list[str] = []
    next_index = 0

    def write_ready() -> None:
        nonlocal next_index
        while next_index < total:
            item, slug = planned[next_index]
            batch = item.batch.strip()
            needs_lookup = bool(slug) and bool(batch) and batch != "-"
            if needs_lookup and not cache.has(slug, batch):
                return
            done = next_index + 1
            row = item.excel_row
            mfg_cell = ws.cell(row, mfg_col)
            expire_cell = ws.cell(row, expire_col)
            remaining_cell = ws.cell(row, remaining_col)
            label = item.name or "(no name)"
            mfg_cell.value = None
            if not batch or batch == "-":
                line = f"{done}/{total}  {label}  — skipped, empty batch"
            elif not slug:
                line = f"{done}/{total}  {label}  — no brand match"
            else:
                result = cache.get(slug, batch)
                brand = result.checkfresh_brand or slug
                if result.production_date:
                    made = result.production_date
                    expires = add_months(made, 36)
                    mfg_cell.value = made
                    mfg_cell.number_format = "dd/mm/yyyy"
                    line = (
                        f"{done}/{total}  {brand}  {batch}  "
                        f"made {format_dmy(made)} in {mfg_letter}{row}  "
                        f"expires {format_dmy(expires)}"
                    )
                else:
                    line = (
                        f"{done}/{total}  {brand}  {batch}  "
                        f"no date ({result.error or 'not found'})"
                    )
            expire_cell.value = expire_formula(mfg_letter, row)
            expire_cell.number_format = "dd/mm/yyyy"
            remaining_cell.value = remaining_formula(mfg_letter, expire_letter, row)
            log_lines.append(line)
            if on_item:
                on_item(done, total, line)
            next_index += 1

    def on_fetch(slug: str, batch: str, result, done: int, unique_total: int) -> None:
        del slug, batch, result, done, unique_total
        write_ready()

    write_ready()
    cache.prefetch(pairs, on_result=on_fetch)
    write_ready()

    if rows:
        first = header_row + 1
        last = max(item.excel_row for item in rows)
        remaining_range = f"{get_column_letter(remaining_col)}{first}:{get_column_letter(remaining_col)}{last}"
        made_ref = f"{mfg_letter}{first}"
        expire_ref = f"{expire_letter}{first}"
        # Order matters: first matching rule wins (stopIfTrue).
        ws.conditional_formatting.add(
            remaining_range,
            FormulaRule(formula=[f'{made_ref}=""'], font=Font(color="9BC2E6"), stopIfTrue=True),
        )
        ws.conditional_formatting.add(
            remaining_range,
            FormulaRule(
                formula=[f"AND(ISNUMBER({expire_ref}),{expire_ref}>=EDATE(TODAY(),17))"],
                font=Font(color="00B050"),
                stopIfTrue=True,
            ),
        )
        ws.conditional_formatting.add(
            remaining_range,
            FormulaRule(
                formula=[f"AND(ISNUMBER({expire_ref}),{expire_ref}<EDATE(TODAY(),17))"],
                font=Font(color="FF0000"),
                stopIfTrue=True,
            ),
        )

    buf = BytesIO()
    wb.save(buf)
    return buf.getvalue(), log_lines


def markdown_table(headers: list[str], rows: list[list[str]]) -> str:
    def cell(value: str) -> str:
        return str(value).replace("|", "\\|").replace("\n", " ")

    head = "| " + " | ".join(cell(h) for h in headers) + " |"
    sep = "| " + " | ".join("---" for _ in headers) + " |"
    body = ["| " + " | ".join(cell(c) for c in row) + " |" for row in rows]
    return "\n".join([head, sep, *body])


st.set_page_config(page_title="CheckFresh batch dates", layout="centered")
st.title("CheckFresh batch dates")
st.write(
    "Upload a spreadsheet with **name** (product title) and **batch** columns. "
    "Pick the manufacturing date column (A to P). Expire is the next column, and remaining is the one after that. "
    "Those two cells are Excel formulas, so pasting into another sheet with the same layout still calculates. "
    "Expiry is **36 months** after manufacture. "
    "Edit slug overrides in "
    f"`{Path(__file__).resolve().parent / 'brand_map.json'}` when a brand does not match."
)

uploaded = st.file_uploader("Drop batch spreadsheet", type=["xlsx"])
header_row = st.number_input(
    "Header row",
    min_value=1,
    step=1,
    value=DEFAULT_HEADER_ROW,
    help="Row that contains name and batch headers.",
)

st.subheader("Expected headers")
st.markdown(
    markdown_table(
        ["Role", "Accepted header names"],
        [
            ["Product name", "name, product, product name, description"],
            ["Batch code", "batch, batch code, lot, lot code"],
        ],
    )
)

preview: SheetPreview | None = None
if uploaded is not None:
    try:
        preview = read_sheet_preview(uploaded.getvalue(), int(header_row))
        st.success(
            "Found "
            f"{len(preview.rows)} data row(s). Mapped: "
            f"{get_column_letter(preview.name_col)}: name, "
            f"{get_column_letter(preview.batch_col)}: batch"
        )
    except Exception as exc:
        st.error(str(exc))
        preview = None

mfg_col = expire_col = remaining_col = None
columns_ok = False
if preview is not None:
    labels = [label for _, label in preview.columns]
    by_label = {label: col for col, label in preview.columns}
    mfg_default = default_column(preview.columns, MFG_HEADER_ALIASES, 6)
    if mfg_default > MFG_LAST_COL:
        mfg_default = 6
    st.subheader("Where to write")
    mfg_label = st.selectbox(
        "Manufacturing date column",
        labels,
        index=next(i for i, (col, _) in enumerate(preview.columns) if col == mfg_default),
        help="A through P. Expire is the next column. Remaining is the column after expire.",
    )
    mfg_col = by_label[mfg_label]
    expire_col = mfg_col + 1
    remaining_col = mfg_col + 2
    columns_ok = True
    st.caption(
        f"Manufacturing date in {get_column_letter(mfg_col)}. "
        f"Expire in {get_column_letter(expire_col)} = EDATE({get_column_letter(mfg_col)}row, 36). "
        f"Remaining in {get_column_letter(remaining_col)}."
    )

run = st.button(
    "Look up dates and build Excel",
    type="primary",
    disabled=(
        uploaded is None
        or preview is None
        or not preview.rows
        or not columns_ok
        or st.session_state.get("running", False)
    ),
)

if run and uploaded is not None and preview is not None and mfg_col and expire_col and remaining_col:
    st.session_state["running"] = True
    progress = st.progress(0.0, text="Starting…")
    live_log = st.empty()
    shown: list[str] = []
    cache = DecodeCache()

    def on_item(done: int, total: int, line: str) -> None:
        shown.append(line)
        progress.progress(done / total, text=line)
        live_log.code("\n".join(shown))

    try:
        out_bytes, logs = build_output_workbook(
            uploaded.getvalue(),
            preview.rows,
            int(header_row),
            mfg_col,
            expire_col,
            remaining_col,
            cache,
            on_item,
        )
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        base = uploaded.name or "batch"
        out_name = re.sub(r"\.xlsx$", "", base, flags=re.I) + f"-manufacturing-{stamp}.xlsx"
        ok = sum(1 for line in logs if " made " in line)
        st.session_state["check_fresh_result"] = {
            "bytes": out_bytes,
            "name": out_name,
            "logs": logs,
            "ok": ok,
            "total": len(preview.rows),
        }
        progress.progress(1.0, text=f"Done. {ok} of {len(preview.rows)} dated.")
        live_log.empty()
    finally:
        st.session_state["running"] = False

result = st.session_state.get("check_fresh_result")
if result and not st.session_state.get("running"):
    st.download_button(
        "Download filled spreadsheet",
        data=result["bytes"],
        file_name=result["name"],
        mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    )
    st.code("\n".join(result["logs"]) if result["logs"] else "(no rows)")
    st.success(f"Decoded {result['ok']} of {result['total']} row(s).")