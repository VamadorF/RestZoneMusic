# -*- coding: utf-8 -*-
"""Genera RestZoneMusic_Data.lua desde community-listfile.xlsx (columna ID + ruta)."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    import openpyxl
except ImportError:
    print("Instala openpyxl: pip install openpyxl", file=sys.stderr)
    sys.exit(1)


def norm_path(p: str) -> str:
    return p.replace("\\", "/").strip()


def is_music_path(p: str) -> bool:
    return "sound/music" in norm_path(p).lower()


def category_and_label(path: str) -> tuple[str, str]:
    """Devuelve (categoría_relativa, etiqueta_completa para mostrar)."""
    p = norm_path(path)
    low = p.lower()
    if "sound/music/" not in low:
        base = p.split("/")[-1] if "/" in p else p
        return "otros", base
    rel = p[low.index("sound/music/") + len("sound/music/") :]
    parts = [x for x in rel.split("/") if x]
    if not parts:
        return "(vacío)", p
    if len(parts) == 1:
        cat = "(raíz)"
        fname = parts[0]
    else:
        cat = "/".join(parts[:-1])
        fname = parts[-1]
    # Capitalizar solo primera letra de cada segmento de categoría para legibilidad
    cat_disp = "/".join(s.replace("_", " ") for s in cat.split("/"))
    label = f"{cat_disp} — {fname}"
    return cat_disp, label


def lua_quote(s: str) -> str:
    """String Lua con comillas dobles; escapa \\, \\n, \\r, \\t, \"."""
    s = s.replace("\\", "\\\\").replace('"', '\\"')
    s = s.replace("\r", "\\r").replace("\n", "\\n").replace("\t", "\\t")
    return f'"{s}"'


def fmt_numbers_line(ids: list[int], per_line: int = 14) -> list[str]:
    lines: list[str] = []
    for i in range(0, len(ids), per_line):
        chunk = ", ".join(str(x) for x in ids[i : i + per_line])
        lines.append("        " + chunk + ",")
    return lines


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--xlsx",
        type=Path,
        default=Path(r"C:\Users\salch\Downloads\community-listfile.xlsx"),
    )
    ap.add_argument(
        "-o",
        "--out",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "RestZoneMusic_Data.lua",
    )
    args = ap.parse_args()

    wb = openpyxl.load_workbook(str(args.xlsx), read_only=True)
    ws = wb.active
    rows: list[tuple[int, str]] = []
    for row in ws.iter_rows(values_only=True):
        if not row or row[0] is None:
            continue
        try:
            fid = int(row[0])
        except (TypeError, ValueError):
            continue
        p = row[1]
        if not isinstance(p, str) or not is_music_path(p):
            continue
        rows.append((fid, norm_path(p)))
    wb.close()

    rows.sort(key=lambda t: t[0])
    ids = [fid for fid, _ in rows]

    out_lines: list[str] = [
        "-- RestZoneMusic_Data.lua",
        "-- Generado por tools/gen_music_data.py — no editar a mano.",
        '-- Fuente: community-listfile.xlsx (filas con ruta bajo "sound/music/").',
        "-- Nota: un .xlsx tiene como máximo 1.048.576 filas; la lista puede estar truncada.",
        "",
        "RestZoneMusic_Data = {",
        "    TRACKS = {",
    ]
    out_lines.extend(fmt_numbers_line(ids))
    out_lines.extend(
        [
            "    },",
            "",
            "    TRACK_NAMES = {",
        ]
    )

    # TRACK_NAMES: varias entradas por línea cuando quepan (~100 cols target)
    buf: list[str] = []
    line_len = 0
    max_line = 105

    def flush_names() -> None:
        nonlocal buf, line_len
        if buf:
            out_lines.append("        " + " ".join(buf))
            buf = []
            line_len = 0

    for fid, path in rows:
        _, label = category_and_label(path)
        piece = f"[{fid}] = {lua_quote(label)},"
        if buf and line_len + 1 + len(piece) > max_line:
            flush_names()
        buf.append(piece)
        line_len += len(piece) + 1
    flush_names()

    out_lines.append("    },")
    out_lines.append("}")
    out_lines.append("")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    text = "\n".join(out_lines)
    args.out.write_text(text, encoding="utf-8")
    print(f"Escrito {args.out} ({len(ids)} pistas).", file=sys.stderr)


if __name__ == "__main__":
    main()
