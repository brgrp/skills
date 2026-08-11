#!/usr/bin/env python3
"""Text-track extractor for the powerpoint-to-md skill.

Reads a .pptx and writes ``extract.json`` to the given tmp directory. Also
dumps every embedded image to ``--images-out``. Emits JSON only — no CLI
output on success.

Two sources of truth:
  - Microsoft MarkItDown → per-slide structured markdown blob.
  - python-pptx         → speaker notes, tables, chart series, embedded
                           images, layout names, and title/subtitle.

The calling agent (see SKILL.md) reads ``extract.json`` for verbatim text
and the slide PNGs for visual intent, then writes the markdown.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from pptx import Presentation
from pptx.enum.shapes import MSO_SHAPE_TYPE


def log(msg: str) -> None:
    print(f"[extract_text] {msg}", file=sys.stderr)


# MarkItDown emits an HTML comment before each slide's markdown.
_MD_SLIDE_MARKER = re.compile(r"<!--\s*Slide number:\s*(\d+)\s*-->", re.IGNORECASE)


def split_markitdown_per_slide(md_text: str) -> dict[int, str]:
    """Split MarkItDown's pptx output into per-slide chunks."""
    if not md_text:
        return {}
    matches = list(_MD_SLIDE_MARKER.finditer(md_text))
    if not matches:
        return {1: md_text.strip()}
    result: dict[int, str] = {}
    for i, m in enumerate(matches):
        start = m.end()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(md_text)
        result[int(m.group(1))] = md_text[start:end].strip()
    return result


# ---------- python-pptx helpers ----------


def _iter_shapes(shapes):
    """Recurse into group shapes to yield every leaf shape."""
    for s in shapes:
        if s.shape_type == MSO_SHAPE_TYPE.GROUP:
            yield from _iter_shapes(s.shapes)
        else:
            yield s


def _text_of(shape) -> str:
    if not getattr(shape, "has_text_frame", False):
        return ""
    lines: list[str] = []
    for p in shape.text_frame.paragraphs:
        line = "".join(r.text or "" for r in p.runs) or (p.text or "")
        lines.append(line)
    return "\n".join(lines).strip()


def _bullets_of(shape) -> list[str]:
    if not getattr(shape, "has_text_frame", False):
        return []
    out: list[str] = []
    for p in shape.text_frame.paragraphs:
        line = ("".join(r.text or "" for r in p.runs) or (p.text or "")).strip()
        if line:
            out.append(line)
    return out


def _extract_table(shape) -> dict[str, Any] | None:
    if not getattr(shape, "has_table", False):
        return None
    rows = list(shape.table.rows)
    if not rows:
        return None
    parsed = [[(c.text or "").strip().replace("\n", " ") for c in row.cells] for row in rows]
    return {"headers": parsed[0], "rows": parsed[1:]}


def _extract_chart(shape) -> dict[str, Any] | None:
    if not getattr(shape, "has_chart", False):
        return None
    try:
        chart = shape.chart
    except Exception:  # noqa: BLE001
        return None

    chart_type = ""
    try:
        if chart.chart_type is not None:
            # e.g. "XL_CHART_TYPE.BAR_CLUSTERED (57)" → "BAR_CLUSTERED"
            raw = str(chart.chart_type).split(".", 1)[-1].split(" ", 1)[0]
            chart_type = raw
    except Exception:  # noqa: BLE001
        pass

    title = ""
    try:
        if chart.has_title:
            title = chart.chart_title.text_frame.text.strip()
    except Exception:  # noqa: BLE001
        pass

    categories: list[str] = []
    try:
        plots = list(chart.plots)
        if plots:
            categories = [str(c) for c in plots[0].categories]
    except Exception:  # noqa: BLE001
        pass

    series: list[dict[str, Any]] = []
    note = ""
    try:
        for s in chart.series:
            try:
                values = [v for v in s.values]
            except Exception:  # noqa: BLE001
                values = []
            series.append({"name": getattr(s, "name", "") or "", "values": values})
    except Exception as exc:  # noqa: BLE001
        note = f"chart series extraction partial: {exc}"

    return {
        "type": chart_type,
        "title": title,
        "categories": categories,
        "series": series,
        "note": note,
    }


def _extract_images(shape, slide_index: int, out_dir: Path, seen: set[str]) -> list[dict[str, str]]:
    """Dump pictures inside ``shape`` (recursively for groups) to ``out_dir``."""
    results: list[dict[str, str]] = []
    shapes_iter = list(_iter_shapes([shape])) if shape.shape_type == MSO_SHAPE_TYPE.GROUP else [shape]

    for s in shapes_iter:
        picture = None
        if getattr(s, "shape_type", None) == MSO_SHAPE_TYPE.PICTURE:
            picture = s
        elif hasattr(s, "image"):
            try:
                _ = s.image
                picture = s
            except Exception:  # noqa: BLE001
                pass
        if picture is None:
            continue
        try:
            image = picture.image
        except Exception:  # noqa: BLE001
            continue

        blob = image.blob
        ext = (image.ext or "png").lower().lstrip(".")
        digest = hashlib.sha1(blob).hexdigest()[:8]  # noqa: S324 (not security)
        pic_idx = len(results) + 1
        fname = f"slide-{slide_index:02d}-pic{pic_idx}-{digest}.{ext}"
        dest = out_dir / fname
        if fname not in seen:
            dest.write_bytes(blob)
            seen.add(fname)
        name = getattr(picture, "name", "") or ""
        results.append({"path": str(dest), "alt": name.strip(), "shape_name": name})
    return results


def _dedup(items: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for it in items:
        if it not in seen:
            seen.add(it)
            out.append(it)
    return out


def extract_with_pptx(pptx_path: Path, images_out: Path) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    prs = Presentation(str(pptx_path))
    cp = prs.core_properties

    deck = {
        "source": str(pptx_path),
        "title": (cp.title or "").strip(),
        "author": (cp.author or "").strip(),
        "slide_count": len(prs.slides),
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
    }

    images_out.mkdir(parents=True, exist_ok=True)
    seen: set[str] = set()
    slides: list[dict[str, Any]] = []

    for idx, slide in enumerate(prs.slides, start=1):
        layout = ""
        try:
            layout = slide.slide_layout.name or ""
        except Exception:  # noqa: BLE001
            pass

        title = ""
        try:
            if slide.shapes.title is not None:
                title = (slide.shapes.title.text or "").strip()
        except Exception:  # noqa: BLE001
            pass

        subtitle = ""
        bullets: list[str] = []
        tables: list[dict[str, Any]] = []
        charts: list[dict[str, Any]] = []
        images: list[dict[str, str]] = []

        for shape in _iter_shapes(slide.shapes):
            # Subtitle = placeholder idx 1 on Title-Slide layouts.
            if getattr(shape, "is_placeholder", False):
                try:
                    ph = shape.placeholder_format
                    if ph is not None and ph.idx == 1 and not subtitle:
                        sub = _text_of(shape)
                        if sub and sub != title:
                            subtitle = sub
                except Exception:  # noqa: BLE001
                    pass

            # Bullets = every text-bearing shape that isn't title/subtitle.
            if getattr(shape, "has_text_frame", False) and _text_of(shape) != title:
                for b in _bullets_of(shape):
                    if b != title and b != subtitle:
                        bullets.append(b)

            tbl = _extract_table(shape)
            if tbl is not None:
                tables.append(tbl)

            chart = _extract_chart(shape)
            if chart is not None:
                charts.append(chart)

            images.extend(_extract_images(shape, idx, images_out, seen))

        notes = ""
        try:
            if slide.has_notes_slide:
                tf = slide.notes_slide.notes_text_frame
                if tf is not None:
                    notes = (tf.text or "").strip()
        except Exception:  # noqa: BLE001
            pass

        slides.append({
            "index": idx,
            "layout": layout,
            "title": title,
            "subtitle": subtitle,
            "content_markdown": "",  # filled in from markitdown below
            "bullets": _dedup(bullets),
            "tables": tables,
            "charts": charts,
            "images": images,
            "notes": notes,
        })

    return deck, slides


# ---------- markitdown ----------


def extract_with_markitdown(pptx_path: Path) -> str:
    try:
        from markitdown import MarkItDown
    except Exception as exc:  # noqa: BLE001
        log(f"WARN: markitdown import failed: {exc} — python-pptx only")
        return ""
    try:
        md = MarkItDown(enable_plugins=False)
        result = md.convert(str(pptx_path))
        return getattr(result, "text_content", None) or getattr(result, "markdown", None) or ""
    except Exception as exc:  # noqa: BLE001
        log(f"WARN: markitdown conversion failed: {exc} — python-pptx only")
        traceback.print_exc(file=sys.stderr)
        return ""


# ---------- main ----------


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="pptx → extract.json")
    ap.add_argument("--input", required=True, help="Path to input .pptx")
    ap.add_argument("--tmp-dir", required=True, help="Tmp dir to write extract.json into")
    ap.add_argument("--images-out", required=True, help="Directory to dump embedded images")
    args = ap.parse_args(argv)

    input_path = Path(args.input).resolve()
    tmp_dir = Path(args.tmp_dir).resolve()
    images_out = Path(args.images_out).resolve()

    if not input_path.exists():
        log(f"ERROR: input not found: {input_path}")
        return 2

    tmp_dir.mkdir(parents=True, exist_ok=True)
    images_out.mkdir(parents=True, exist_ok=True)

    log(f"input:  {input_path}")
    log(f"tmp:    {tmp_dir}")
    log(f"images: {images_out}")

    try:
        deck, slides = extract_with_pptx(input_path, images_out)
    except Exception as exc:  # noqa: BLE001
        log(f"ERROR: python-pptx extraction failed: {exc}")
        traceback.print_exc(file=sys.stderr)
        return 3

    log(f"parsed {deck['slide_count']} slides via python-pptx")

    md_by_slide = split_markitdown_per_slide(extract_with_markitdown(input_path))
    log(f"markitdown produced markdown for {len(md_by_slide)} slide chunk(s)")

    for s in slides:
        s["content_markdown"] = md_by_slide.get(s["index"], "")

    out_json = tmp_dir / "extract.json"
    out_json.write_text(
        json.dumps({"deck": deck, "slides": slides}, ensure_ascii=False, indent=2, default=str),
        encoding="utf-8",
    )
    log(f"wrote {out_json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
