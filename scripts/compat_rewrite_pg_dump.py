#!/usr/bin/env python3
"""Rewrite pg_dump --data-only COPY blocks to columns present on the local DB.

Reads a columns map (schema.table -> ordered local column names) from stdin as
lines: schema.table<TAB>col1,col2,...

Writes a compat dump to stdout. Skips tables missing locally; drops dump-only columns.
"""

from __future__ import annotations

import re
import sys
from typing import Dict, List, Optional, Tuple

COPY_RE = re.compile(
    r'^COPY\s+(?:"(?P<s1>[^"]+)"|(?P<s2>\w+))\.(?:"(?P<t1>[^"]+)"|(?P<t2>\w+))\s*\((?P<cols>.*)\)\s+FROM stdin;\s*$'
)


def load_columns_map(path: str) -> Dict[str, List[str]]:
    out: Dict[str, List[str]] = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line or "\t" not in line:
                continue
            key, cols = line.split("\t", 1)
            out[key] = [c for c in cols.split(",") if c]
    return out


def parse_copy_cols(raw: str) -> List[str]:
    cols: List[str] = []
    for part in raw.split(","):
        c = part.strip()
        if c.startswith('"') and c.endswith('"'):
            c = c[1:-1]
        cols.append(c)
    return cols


def split_copy_fields(line: str) -> List[str]:
    """Split one COPY text-format row on unescaped tabs."""
    s = line.rstrip("\n").rstrip("\r")
    fields: List[str] = []
    buf: List[str] = []
    i = 0
    while i < len(s):
        ch = s[i]
        if ch == "\\" and i + 1 < len(s):
            buf.append(ch)
            buf.append(s[i + 1])
            i += 2
            continue
        if ch == "\t":
            fields.append("".join(buf))
            buf = []
            i += 1
            continue
        buf.append(ch)
        i += 1
    fields.append("".join(buf))
    return fields


def rewrite(
    dump_path: str,
    columns: Dict[str, List[str]],
    out_path: str,
) -> Tuple[int, int, int]:
    skipped_tables = 0
    rewritten_tables = 0
    passthrough_tables = 0

    with open(dump_path, "r", encoding="utf-8", errors="replace") as inp, open(
        out_path, "w", encoding="utf-8"
    ) as out:
        in_copy = False
        keep_idx: Optional[List[int]] = None
        dump_ncols = 0
        skip_table = False

        for line in inp:
            if not in_copy:
                m = COPY_RE.match(line)
                if not m:
                    out.write(line)
                    continue
                schema = m.group("s1") or m.group("s2")
                table = m.group("t1") or m.group("t2")
                key = f"{schema}.{table}"
                dump_cols = parse_copy_cols(m.group("cols"))
                local_cols = columns.get(key)

                if not local_cols:
                    skip_table = True
                    in_copy = True
                    keep_idx = None
                    skipped_tables += 1
                    out.write(f"-- skipped missing table {key}\n")
                    continue

                local_set = set(local_cols)
                keep_idx = [i for i, c in enumerate(dump_cols) if c in local_set]
                kept_names = [dump_cols[i] for i in keep_idx]
                # Preserve local order for readability (and NOT NULL defaults): order by local.
                order = {c: i for i, c in enumerate(local_cols)}
                paired = sorted(zip(keep_idx, kept_names), key=lambda p: order.get(p[1], 10**9))
                keep_idx = [p[0] for p in paired]
                kept_names = [p[1] for p in paired]

                if len(kept_names) == len(dump_cols) and kept_names == dump_cols:
                    out.write(line)
                    passthrough_tables += 1
                else:
                    if len(kept_names) < len(dump_cols):
                        dropped = [c for c in dump_cols if c not in local_set]
                        out.write(
                            f"-- compat: dropped columns not on local {key}: {', '.join(dropped)}\n"
                        )
                    quoted = ", ".join(f'"{c}"' for c in kept_names)
                    out.write(f'COPY "{schema}"."{table}" ({quoted}) FROM stdin;\n')
                    rewritten_tables += 1

                in_copy = True
                dump_ncols = len(dump_cols)
                skip_table = False
                continue

            # Inside COPY data
            if line == "\\.\n" or line == "\\.\r\n":
                if not skip_table:
                    out.write(line)
                in_copy = False
                keep_idx = None
                skip_table = False
                continue

            if skip_table:
                continue

            assert keep_idx is not None
            if len(keep_idx) == dump_ncols and keep_idx == list(range(dump_ncols)):
                out.write(line)
                continue

            fields = split_copy_fields(line)
            if len(fields) != dump_ncols:
                # Malformed / continuation — pass through and hope (rare for our dumps).
                out.write(line)
                continue
            new_fields = [fields[i] for i in keep_idx]
            out.write("\t".join(new_fields) + "\n")

    return skipped_tables, rewritten_tables, passthrough_tables


def main() -> int:
    if len(sys.argv) != 4:
        print(
            "usage: compat_rewrite_pg_dump.py <columns.map> <in.dump.sql> <out.dump.sql>",
            file=sys.stderr,
        )
        return 2
    columns = load_columns_map(sys.argv[1])
    skipped, rewritten, ok = rewrite(sys.argv[2], columns, sys.argv[3])
    print(
        f"compat rewrite: passthrough={ok} rewritten={rewritten} skipped_tables={skipped}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
