# -*- coding: utf-8 -*-
"""Genera RestZoneMusic_Data.lua desde community-listfile.xlsx (columna ID + ruta).

Duraciones (TRACK_DURATIONS): exporta los MP3/OGG del cliente (p. ej. wow.export) y ejecuta:

  pip install -r tools/requirements.txt
  python tools/gen_music_data.py --xlsx ruta/listfile.xlsx --export-root D:\\export\\wow --layout full

  --layout full        Raíz contiene sound/music/... (igual que en el listfile).
  --layout music_only  Raíz es el contenido de sound/music/ (sin carpetas sound/music).

Si no pasas --export-root, TRACK_DURATIONS queda vacío; el addon usa la opción en juego.

Herramientas de duración: --duration-tool auto (tinytag, luego ffprobe si hace falta) | tinytag | ffprobe
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
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
    cat_disp = "/".join(s.replace("_", " ") for s in cat.split("/"))
    label = f"{cat_disp} — {fname}"
    return cat_disp, label


def lua_quote(s: str) -> str:
    s = s.replace("\\", "\\\\").replace('"', '\\"')
    s = s.replace("\r", "\\r").replace("\n", "\\n").replace("\t", "\\t")
    return f'"{s}"'


def fmt_numbers_line(ids: list[int], per_line: int = 14) -> list[str]:
    lines: list[str] = []
    for i in range(0, len(ids), per_line):
        chunk = ", ".join(str(x) for x in ids[i : i + per_line])
        lines.append("        " + chunk + ",")
    return lines


def strip_sound_music_prefix(rel: str) -> str:
    low = rel.lower()
    prefix = "sound/music/"
    if low.startswith(prefix):
        return rel[len(prefix) :].lstrip("/")
    return rel


def resolve_audio_file(
    export_root: Path,
    file_id: int,
    listfile_path: str,
    layout: str,
) -> Path | None:
    """Resuelve ruta al archivo exportado."""
    rel_full = norm_path(listfile_path).lstrip("/")
    if layout == "music_only":
        rel_disk = strip_sound_music_prefix(rel_full)
    elif layout == "full":
        rel_disk = rel_full
    else:
        raise ValueError(f"layout desconocido: {layout}")

    parts = [p for p in rel_disk.split("/") if p]
    if parts:
        p1 = export_root.joinpath(*parts)
        if p1.is_file():
            return p1

    for ext in (".mp3", ".ogg", ".flac", ".wav"):
        flat = export_root / f"{file_id}{ext}"
        if flat.is_file():
            return flat

    if parts:
        p2 = export_root.joinpath(*[s.lower() for s in parts])
        if p2.is_file():
            return p2

    return None


def duration_tinytag(path: Path) -> float | None:
    try:
        from tinytag import TinyTag
    except ImportError:
        return None
    try:
        t = TinyTag.get(str(path))
    except Exception:
        return None
    if t.duration is None or float(t.duration) <= 0:
        return None
    return float(t.duration)


def duration_ffprobe(path: Path) -> float | None:
    exe = shutil.which("ffprobe")
    if not exe:
        return None
    try:
        out = subprocess.check_output(
            [
                exe,
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                str(path),
            ],
            stderr=subprocess.STDOUT,
            text=True,
            timeout=60,
        )
        d = float(out.strip())
        if d <= 0:
            return None
        return d
    except Exception:
        return None


def probe_duration(path: Path, tool: str) -> float | None:
    if tool == "tinytag":
        return duration_tinytag(path)
    if tool == "ffprobe":
        return duration_ffprobe(path)
    # auto
    d = duration_tinytag(path)
    if d is not None:
        return d
    return duration_ffprobe(path)


def build_durations(
    rows: list[tuple[int, str]],
    export_root: Path | None,
    layout: str,
    tool: str,
) -> tuple[dict[int, float], int, int]:
    """Devuelve (mapa id->segundos, encontrados, omitidos_sin_archivo)."""
    out: dict[int, float] = {}
    if export_root is None or not export_root.is_dir():
        return out, 0, len(rows)

    found_files = 0
    missing = 0
    errors = 0
    for fid, list_path in rows:
        audio = resolve_audio_file(export_root, fid, list_path, layout)
        if audio is None:
            missing += 1
            continue
        found_files += 1
        dur = probe_duration(audio, tool)
        if dur is None:
            errors += 1
            continue
        out[fid] = round(dur, 2)

    if errors:
        print(
            f"Aviso: {errors} archivos encontrados pero sin duración (corrige --duration-tool o instala ffprobe).",
            file=sys.stderr,
        )
    return out, len(out), missing


def fmt_duration_block(durations: dict[int, float]) -> list[str]:
    if not durations:
        return [
            "    -- Rellena con: python tools/gen_music_data.py --export-root ...",
            "    TRACK_DURATIONS = {",
            "    },",
        ]
    lines: list[str] = [
        f"    -- Duraciones medidas localmente ({len(durations)} pistas).",
        "    TRACK_DURATIONS = {",
    ]
    buf: list[str] = []
    line_len = 0
    max_line = 102
    for fid in sorted(durations):
        piece = f"[{fid}] = {durations[fid]:.2f},"
        if buf and line_len + len(piece) + 1 > max_line:
            lines.append("        " + " ".join(buf))
            buf = []
            line_len = 0
        buf.append(piece)
        line_len += len(piece) + 1
    if buf:
        lines.append("        " + " ".join(buf))
    lines.append("    },")
    return lines


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
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
    ap.add_argument(
        "--export-root",
        type=Path,
        default=None,
        help="Carpeta del export (ver --layout).",
    )
    ap.add_argument(
        "--layout",
        choices=("full", "music_only"),
        default="full",
        help="full: raíz/sound/music/...; music_only: raíz/citymusic/...",
    )
    ap.add_argument(
        "--duration-tool",
        choices=("auto", "tinytag", "ffprobe"),
        default="auto",
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

    durations, n_dur, n_miss = build_durations(
        rows,
        args.export_root,
        args.layout,
        args.duration_tool,
    )

    header_extra = ""
    if args.export_root:
        header_extra = (
            f"\n-- TRACK_DURATIONS: {n_dur} pistas; sin archivo en export: {n_miss}."
        )

    out_lines: list[str] = [
        "-- RestZoneMusic_Data.lua",
        "-- Generado por tools/gen_music_data.py — no editar a mano.",
        '-- Fuente: community-listfile.xlsx (filas con ruta bajo "sound/music/").',
        "-- Nota: un .xlsx tiene como máximo 1.048.576 filas; la lista puede estar truncada."
        + header_extra,
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
    out_lines.append("")
    out_lines.extend(fmt_duration_block(durations))
    out_lines.append("}")
    out_lines.append("")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    text = "\n".join(out_lines)
    args.out.write_text(text, encoding="utf-8")
    print(
        f"Escrito {args.out} ({len(ids)} pistas; duraciones: {n_dur}).",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
