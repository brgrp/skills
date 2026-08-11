#!/usr/bin/env bash
# render_slides.sh — render every slide of a .pptx to a PNG.
#
# Pipeline: pptx --(soffice)--> pdf --(rasterizer)--> slide-NN.png
# Rasterizer priority: pdftoppm > ImageMagick > pdf2image
#
# Called by pptx2md.sh. Not intended for direct end-user use.
#
# Environment (all required, set by the caller):
#   SOFFICE_BIN   path to soffice / libreoffice executable
#   RASTERIZER    one of: pdftoppm | magick | convert | pdf2image
#   UV_BIN        path to uv (only used for the pdf2image fallback)
#   SKILL_DIR     powerpoint-to-md skill root (contains pyproject.toml)
#
# Args:
#   $1  input .pptx (absolute path)
#   $2  tmp dir (owned by the caller; script writes intermediate .pdf here)
#   $3  slides output dir (script writes slide-01.png … here)

set -euo pipefail

log()  { printf '[render_slides] %s\n' "$*" >&2; }
err()  { printf '[render_slides] ERROR: %s\n' "$*" >&2; }

if [[ $# -lt 3 ]]; then
    err "usage: render_slides.sh <input.pptx> <tmp_dir> <slides_out_dir>"
    exit 2
fi

INPUT="$1"
TMP_DIR="$2"
SLIDES_OUT="$3"

: "${SOFFICE_BIN:?SOFFICE_BIN not set}"
: "${RASTERIZER:?RASTERIZER not set}"

if [[ ! -f "$INPUT" ]]; then
    err "input not found: $INPUT"
    exit 2
fi

mkdir -p "$TMP_DIR" "$SLIDES_OUT"

# --- Step 1: pptx -> pdf via soffice ---------------------------------------

# soffice --convert-to pdf writes into --outdir, filename = basename minus ext + .pdf.
# We use a per-run user profile to avoid clashes with an interactive LibreOffice
# session or with parallel runs.
PROFILE_DIR="$TMP_DIR/lo-profile"
mkdir -p "$PROFILE_DIR"

log "converting to pdf via $SOFFICE_BIN..."
if ! "$SOFFICE_BIN" \
        --headless \
        --nologo \
        --nofirststartwizard \
        --nodefault \
        --norestore \
        -env:UserInstallation="file://$PROFILE_DIR" \
        --convert-to pdf \
        --outdir "$TMP_DIR" \
        "$INPUT" >&2; then
    err "soffice failed to convert pptx → pdf"
    exit 3
fi

BASENAME="$(basename "$INPUT")"
BASENAME_NOEXT="${BASENAME%.*}"
PDF="$TMP_DIR/${BASENAME_NOEXT}.pdf"

if [[ ! -f "$PDF" ]]; then
    err "expected pdf not found at $PDF"
    exit 3
fi

log "pdf: $PDF"

# --- Step 2: pdf -> slide-NN.png via chosen rasterizer ---------------------

render_pdftoppm() {
    # -r 300  DPI
    # -png    force png
    # naming: slide-<seq>.png, zero-padded to 2 digits by default in newer poppler;
    # to be safe, we rename below.
    local prefix="$SLIDES_OUT/slide"
    if ! pdftoppm -r 300 -png "$PDF" "$prefix" >&2; then
        return 1
    fi
    # pdftoppm names files slide-1.png / slide-01.png depending on version.
    # Normalize to zero-padded slide-NN.png.
    _normalize_slide_names
    return 0
}

render_magick() {
    local density=300
    local cmd
    if command -v magick >/dev/null 2>&1; then
        cmd=(magick)
    else
        cmd=(convert)
    fi
    # -density BEFORE input, -quality on png controls compression
    if ! "${cmd[@]}" -density "$density" "$PDF" -alpha remove -background white "$SLIDES_OUT/slide-%02d.png" >&2; then
        err "ImageMagick rasterization failed. If you see 'not authorized PDF', fix the policy file — see references/troubleshooting.md."
        return 1
    fi
    # ImageMagick starts at 0; shift to 1-based.
    _shift_zero_based_to_one_based
    return 0
}

render_pdf2image() {
    : "${UV_BIN:?UV_BIN required for pdf2image fallback}"
    : "${SKILL_DIR:?SKILL_DIR required for pdf2image fallback}"
    "$UV_BIN" --project "$SKILL_DIR" run --quiet python - "$PDF" "$SLIDES_OUT" <<'PY' >&2 || return 1
import sys
from pathlib import Path
from pdf2image import convert_from_path

pdf, out_dir = sys.argv[1], Path(sys.argv[2])
out_dir.mkdir(parents=True, exist_ok=True)
images = convert_from_path(pdf, dpi=300, fmt="png")
for i, img in enumerate(images, start=1):
    img.save(out_dir / f"slide-{i:02d}.png", "PNG")
print(f"[pdf2image] wrote {len(images)} slides to {out_dir}")
PY
    return 0
}

_normalize_slide_names() {
    # Rename slide-<any-digits>.png → slide-NN.png (2-digit zero-pad).
    # Only handles the exact prefix "slide-".
    shopt -s nullglob
    for f in "$SLIDES_OUT"/slide-*.png; do
        local base num new
        base="$(basename "$f")"
        num="${base#slide-}"
        num="${num%.png}"
        # already 2+ digits AND numeric? leave it.
        if [[ "$num" =~ ^[0-9]+$ ]]; then
            new="$(printf 'slide-%02d.png' "$((10#$num))")"
            if [[ "$base" != "$new" ]]; then
                mv "$f" "$SLIDES_OUT/$new"
            fi
        fi
    done
    shopt -u nullglob
}

_shift_zero_based_to_one_based() {
    # ImageMagick's %02d starts at 0. If slide-00.png exists, shift up by 1.
    [[ -f "$SLIDES_OUT/slide-00.png" ]] || return 0
    local sorted=()
    # Sort descending so we don't overwrite before shifting.
    mapfile -t sorted < <(find "$SLIDES_OUT" -maxdepth 1 -name 'slide-*.png' -type f | sort -r)
    for f in "${sorted[@]}"; do
        local base num
        base="$(basename "$f")"
        num="${base#slide-}"
        num="${num%.png}"
        if [[ "$num" =~ ^[0-9]+$ ]]; then
            mv "$f" "$SLIDES_OUT/$(printf 'slide-%02d.png' "$((10#$num + 1))")"
        fi
    done
}

log "rasterizing with $RASTERIZER..."
case "$RASTERIZER" in
    pdftoppm)              render_pdftoppm ;;
    magick|convert)        render_magick ;;
    pdf2image)             render_pdf2image ;;
    *)
        err "unknown rasterizer: $RASTERIZER"
        exit 3
        ;;
esac

# --- Sanity check ----------------------------------------------------------

count="$(find "$SLIDES_OUT" -maxdepth 1 -name 'slide-*.png' -type f | wc -l | tr -d '[:space:]')"
if [[ "$count" -eq 0 ]]; then
    err "no slide PNGs produced"
    exit 3
fi
log "produced $count slide PNG(s) in $SLIDES_OUT"
