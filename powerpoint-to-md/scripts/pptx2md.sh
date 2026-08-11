#!/usr/bin/env bash
# pptx2md.sh — orchestrator for the powerpoint-to-md skill.
#
# Commands:
#   doctor                verify dependencies (JSON to stdout, install fixes to stderr)
#   extract  <in.pptx>    run both extraction tracks, print JSON manifest to stdout
#   cleanup  <tmp_dir>    delete a tmp dir returned by `extract`
#
# Contract:
#   - Data (JSON) → stdout.  Messages → stderr.  Non-zero exit on hard failure.
#
# Hard deps: uv, jq, soffice (LibreOffice), and one PDF rasterizer
#            (pdftoppm preferred, ImageMagick fallback; pdf2image is bundled
#            in the uv venv as a last-resort fallback).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

log() { printf '[pptx2md] %s\n' "$*" >&2; }
err() { printf '[pptx2md] ERROR: %s\n' "$*" >&2; }

emit_error_json() {
    jq -n --arg error "$1" --arg code "$2" --arg solution "$3" \
        '{status:"error", error:$error, code:$code, solution:$solution}'
}

require_cmd() { command -v "$1" >/dev/null 2>&1; }

# ---------- dep detection ----------

detect_soffice() {
    for cand in soffice libreoffice; do
        if command -v "$cand" >/dev/null 2>&1; then command -v "$cand"; return 0; fi
    done
    if [[ -x "/Applications/LibreOffice.app/Contents/MacOS/soffice" ]]; then
        echo "/Applications/LibreOffice.app/Contents/MacOS/soffice"; return 0
    fi
    return 1
}

detect_rasterizer() {
    # Preferred → fallback → last-resort (pdf2image via uv venv).
    if command -v pdftoppm >/dev/null 2>&1; then echo "pdftoppm"; return 0; fi
    if command -v magick   >/dev/null 2>&1; then echo "magick";   return 0; fi
    if command -v convert  >/dev/null 2>&1; then echo "convert";  return 0; fi
    if [[ -n "${UV_BIN:-}" ]] \
        && "$UV_BIN" --project "$SKILL_DIR" run --quiet python -c "import pdf2image" 2>/dev/null; then
        echo "pdf2image"; return 0
    fi
    return 1
}

# Sync the skill's uv venv. Idempotent — a no-op once uv.lock is satisfied.
ensure_uv_env() {
    if ! "$UV_BIN" --project "$SKILL_DIR" sync --quiet >&2 2>&1; then
        err "uv sync failed in $SKILL_DIR"
        return 1
    fi
    return 0
}

uv_python() {
    "$UV_BIN" --project "$SKILL_DIR" run --quiet python "$@"
}

# ---------- commands ----------

cmd_doctor() {
    require_cmd jq || {
        emit_error_json "jq is required but not found" "MISSING_DEP" \
            "Install jq: 'brew install jq' or 'apt install jq'"
        return 2
    }

    local ok=1 uv_bin="" soffice_bin="" rasterizer=""

    log "checking uv..."
    if uv_bin="$(command -v uv 2>/dev/null)"; then
        log "  OK: $uv_bin ($("$uv_bin" --version 2>&1))"
        export UV_BIN="$uv_bin"
    else
        err "  MISSING: uv"
        err "  Install: brew install uv                                 (macOS)"
        err "           curl -LsSf https://astral.sh/uv/install.sh | sh (Linux/macOS)"
        err "           https://docs.astral.sh/uv/                      (Windows)"
        ok=0
    fi

    if [[ -n "$uv_bin" ]]; then
        log "syncing python deps (markitdown[pptx], python-pptx, pdf2image)..."
        if ensure_uv_env; then
            log "  OK: venv synced against pyproject.toml + uv.lock"
        else
            err "  FAILED: check network and lockfile"
            ok=0
        fi
    fi

    log "checking LibreOffice..."
    if soffice_bin="$(detect_soffice)"; then
        log "  OK: $soffice_bin"
    else
        err "  MISSING: LibreOffice (soffice) — REQUIRED"
        err "  Install: brew install --cask libreoffice    (macOS)"
        err "           sudo apt install libreoffice       (Ubuntu)"
        err "           https://www.libreoffice.org/download  (Windows)"
        ok=0
    fi

    log "checking PDF rasterizer..."
    if rasterizer="$(detect_rasterizer)"; then
        log "  OK: $rasterizer"
    else
        err "  MISSING: no PDF rasterizer available"
        err "  Install one of:"
        err "    brew install poppler                    (macOS, preferred)"
        err "    sudo apt install poppler-utils          (Ubuntu, preferred)"
        err "    brew install imagemagick ghostscript    (macOS, fallback)"
        ok=0
    fi

    if [[ $ok -eq 1 ]]; then
        jq -n \
            --arg uv "$uv_bin" \
            --arg soffice "$soffice_bin" \
            --arg rasterizer "$rasterizer" \
            --arg skill_dir "$SKILL_DIR" \
            '{status:"ok", uv:$uv, soffice:$soffice, rasterizer:$rasterizer, skill_dir:$skill_dir}'
        return 0
    fi
    emit_error_json "one or more required dependencies missing" "MISSING_DEPS" \
        "Follow the install instructions printed above, then re-run doctor."
    return 1
}

# basename without extension, lowercased, non-alnum → '-'
_slug() {
    local name
    name="$(basename "$1")"
    name="${name%.*}"
    printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed -E 's/-+/-/g; s/^-|-$//g'
}

cmd_extract() {
    local input="${1:-}"
    if [[ -z "$input" ]]; then
        emit_error_json "no input file provided" "MISSING_INPUT" \
            "Usage: pptx2md.sh extract <input.pptx>"
        return 2
    fi
    if [[ ! -f "$input" ]]; then
        emit_error_json "input file not found: $input" "INPUT_NOT_FOUND" \
            "Provide a path to an existing .pptx file"
        return 2
    fi
    case "$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')" in
        *.pptx) ;;
        *)
            emit_error_json "only .pptx files are supported (got: $input)" "UNSUPPORTED_FORMAT" \
                "Convert to .pptx first (Keynote/Google Slides can export .pptx)"
            return 2 ;;
    esac

    require_cmd jq || {
        emit_error_json "jq is required" "MISSING_DEP" "Install jq"
        return 2
    }

    # Hard-fail on missing deps.
    local uv_bin soffice_bin rasterizer
    if ! uv_bin="$(command -v uv 2>/dev/null)"; then
        emit_error_json "uv not found" "MISSING_UV" \
            "Install uv: 'brew install uv' or 'curl -LsSf https://astral.sh/uv/install.sh | sh'"
        return 2
    fi
    export UV_BIN="$uv_bin"

    if ! ensure_uv_env; then
        emit_error_json "uv sync failed" "UV_SYNC_FAILED" \
            "Run '$uv_bin --project $SKILL_DIR sync' manually and check the network."
        return 2
    fi

    if ! soffice_bin="$(detect_soffice)"; then
        emit_error_json "LibreOffice (soffice) not found" "MISSING_LIBREOFFICE" \
            "brew install --cask libreoffice (macOS) or apt install libreoffice (Ubuntu)"
        return 2
    fi
    if ! rasterizer="$(detect_rasterizer)"; then
        emit_error_json "no PDF rasterizer found" "MISSING_RASTERIZER" \
            "brew install poppler (macOS) or apt install poppler-utils (Ubuntu)"
        return 2
    fi

    # Resolve paths.
    local input_abs input_dir slug
    input_abs="$(cd "$(dirname "$input")" && pwd)/$(basename "$input")"
    input_dir="$(dirname "$input_abs")"
    slug="$(_slug "$input_abs")"
    [[ -z "$slug" ]] && slug="deck"

    local output_root="$input_dir/$slug"
    local output_md="$output_root/$slug.md"
    local output_md_with_images="$output_root/$slug.with-images.md"
    local assets_dir="$output_root/$slug-assets"
    local slides_out="$assets_dir/slides"
    local images_out="$assets_dir/images"

    local tmp_dir
    tmp_dir="$(mktemp -d -t "pptx2md-XXXXXX")"
    log "tmp dir: $tmp_dir"
    mkdir -p "$output_root" "$slides_out" "$images_out"

    # Track A: text.
    log "extracting text via uv (markitdown + python-pptx)..."
    if ! uv_python "$SCRIPT_DIR/extract_text.py" \
            --input "$input_abs" \
            --tmp-dir "$tmp_dir" \
            --images-out "$images_out" >&2; then
        emit_error_json "text extraction failed" "EXTRACT_TEXT_FAILED" \
            "See stderr. The .pptx may be corrupt or password-protected."
        return 3
    fi
    if [[ ! -f "$tmp_dir/extract.json" ]]; then
        emit_error_json "extract.json not produced" "EXTRACT_TEXT_FAILED" \
            "extract_text.py did not write extract.json"
        return 3
    fi

    # Track B: slide renders.
    log "rendering slides ($soffice_bin + $rasterizer)..."
    if ! SOFFICE_BIN="$soffice_bin" RASTERIZER="$rasterizer" \
            UV_BIN="$uv_bin" SKILL_DIR="$SKILL_DIR" \
            "$SCRIPT_DIR/render_slides.sh" "$input_abs" "$tmp_dir" "$slides_out" >&2; then
        emit_error_json "slide rendering failed" "RENDER_FAILED" \
            "See stderr. Run 'pptx2md.sh doctor' to re-verify soffice and rasterizer."
        return 3
    fi

    local slide_count
    slide_count="$(find "$slides_out" -maxdepth 1 -name 'slide-*.png' -type f 2>/dev/null | wc -l | tr -d '[:space:]')"

    # Manifest — the calling agent parses this.
    jq -n \
        --arg deck_name "$slug" \
        --arg input "$input_abs" \
        --arg output_root "$output_root" \
        --arg output_md "$output_md" \
        --arg output_md_with_images "$output_md_with_images" \
        --arg assets_dir "$assets_dir" \
        --arg tmp_dir "$tmp_dir" \
        --arg extract_json "$tmp_dir/extract.json" \
        --arg slides_dir "$slides_out" \
        --arg images_dir "$images_out" \
        --argjson slide_count "$slide_count" \
        '{
            status: "success",
            deck_name: $deck_name,
            input: $input,
            output_root: $output_root,
            output_md: $output_md,
            output_md_with_images: $output_md_with_images,
            assets_dir: $assets_dir,
            slides_dir: $slides_dir,
            images_dir: $images_dir,
            tmp_dir: $tmp_dir,
            extract_json: $extract_json,
            slide_count: $slide_count
        }'
}

cmd_cleanup() {
    local tmp_dir="${1:-}"
    if [[ -z "$tmp_dir" ]]; then
        emit_error_json "no tmp dir provided" "MISSING_INPUT" \
            "Usage: pptx2md.sh cleanup <tmp_dir>"
        return 2
    fi
    # Safety: only remove paths that look like our tmp dirs.
    case "$tmp_dir" in
        */pptx2md-*)
            if [[ -d "$tmp_dir" ]]; then
                rm -rf "$tmp_dir"
                log "cleaned up $tmp_dir"
                jq -n --arg tmp_dir "$tmp_dir" '{status:"success", cleaned:$tmp_dir}'
            else
                jq -n --arg tmp_dir "$tmp_dir" '{status:"success", note:"already absent", tmp_dir:$tmp_dir}'
            fi ;;
        *)
            emit_error_json "refusing to remove path outside pptx2md tmp: $tmp_dir" "UNSAFE_PATH" \
                "Only paths matching */pptx2md-* are cleaned up"
            return 2 ;;
    esac
}

usage() {
    cat >&1 <<'EOF'
Usage:
  pptx2md.sh doctor
  pptx2md.sh extract  <input.pptx>
  pptx2md.sh cleanup  <tmp_dir>

Commands:
  doctor    Verify dependencies. JSON status to stdout, install fixes to stderr.
  extract   Run both extraction tracks. Prints a JSON manifest to stdout.
            The agent then reads extract_json + slide PNGs and writes deck.md.
            Call cleanup with the tmp_dir field when done.
  cleanup   Delete a tmp dir returned by extract.
EOF
}

main() {
    local cmd="${1:-}"
    if [[ -z "$cmd" ]]; then usage >&2; return 2; fi
    shift
    case "$cmd" in
        doctor)         cmd_doctor  "$@" ;;
        extract)        cmd_extract "$@" ;;
        cleanup)        cmd_cleanup "$@" ;;
        -h|--help|help) usage; return 0 ;;
        *)  err "unknown command: $cmd"; usage >&2; return 2 ;;
    esac
}

main "$@"
