#!/usr/bin/env bash
# pptx2md.sh — orchestrator for the powerpoint-to-md skill.
#
# Commands:
#   doctor                     verify dependencies, print install fixes
#   extract   <in.pptx>        run both extraction tracks, print JSON manifest to stdout
#   convert   <in.pptx>        one-shot: extract + hint for agent + cleanup on success
#   cleanup   <tmp_dir>        delete a tmp dir returned by `extract`
#
# Contract:
#   - Data (JSON manifest) goes to stdout.
#   - Human-readable messages go to stderr.
#   - Non-zero exit on any hard failure. `doctor` returns non-zero if a hard dep is missing.
#
# Hard deps: python3, soffice (LibreOffice), one of {pdftoppm, magick/convert, python pdf2image}.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- logging ----------

log()  { printf '[pptx2md] %s\n' "$*" >&2; }
warn() { printf '[pptx2md] WARN: %s\n' "$*" >&2; }
err()  { printf '[pptx2md] ERROR: %s\n' "$*" >&2; }

# ---------- json helpers ----------

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        err "required command '$cmd' not found"
        return 1
    fi
    return 0
}

emit_error_json() {
    local error_msg="$1"
    local code="$2"
    local solution="$3"
    jq -n \
        --arg error "$error_msg" \
        --arg code "$code" \
        --arg solution "$solution" \
        '{status:"error", error:$error, code:$code, solution:$solution}'
}

# ---------- dep detection ----------

detect_python() {
    for cand in python3 python; do
        if command -v "$cand" >/dev/null 2>&1; then
            echo "$cand"
            return 0
        fi
    done
    return 1
}

detect_soffice() {
    for cand in soffice libreoffice; do
        if command -v "$cand" >/dev/null 2>&1; then
            echo "$cand"
            return 0
        fi
    done
    # macOS common install path
    if [[ -x "/Applications/LibreOffice.app/Contents/MacOS/soffice" ]]; then
        echo "/Applications/LibreOffice.app/Contents/MacOS/soffice"
        return 0
    fi
    return 1
}

detect_rasterizer() {
    # Prefer pdftoppm, fall back to ImageMagick, then pdf2image (python module).
    if command -v pdftoppm >/dev/null 2>&1; then
        echo "pdftoppm"
        return 0
    fi
    if command -v magick >/dev/null 2>&1; then
        echo "magick"
        return 0
    fi
    if command -v convert >/dev/null 2>&1; then
        echo "convert"
        return 0
    fi
    if [[ -n "${PYTHON_BIN:-}" ]] && "$PYTHON_BIN" -c "import pdf2image" 2>/dev/null; then
        echo "pdf2image"
        return 0
    fi
    return 1
}

check_python_modules() {
    local python_bin="$1"
    local missing=()
    for mod in markitdown pptx; do
        if ! "$python_bin" -c "import $mod" 2>/dev/null; then
            missing+=("$mod")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        # Translate python module name → pip package name.
        local pip_pkgs=()
        for m in "${missing[@]}"; do
            case "$m" in
                markitdown) pip_pkgs+=("'markitdown[pptx]'") ;;
                pptx)       pip_pkgs+=("python-pptx") ;;
                *)          pip_pkgs+=("$m") ;;
            esac
        done
        echo "${pip_pkgs[*]}"
        return 1
    fi
    return 0
}

# ---------- commands ----------

cmd_doctor() {
    require_cmd jq || {
        emit_error_json "jq is required but not found" "MISSING_DEP" "Install jq: 'brew install jq' or 'apt install jq'"
        return 2
    }

    local ok=1

    log "checking python3..."
    local python_bin
    if python_bin="$(detect_python)"; then
        log "  OK: $python_bin ($($python_bin --version 2>&1))"
    else
        err "  MISSING: python3"
        err "  Install: brew install python@3.12   (macOS)"
        err "           sudo apt install python3   (Ubuntu)"
        ok=0
    fi

    log "checking python modules..."
    if [[ -n "${python_bin:-}" ]]; then
        local pip_needed
        if pip_needed="$(check_python_modules "$python_bin")"; then
            log "  OK: markitdown, python-pptx"
        else
            err "  MISSING python modules"
            err "  Install: pip install $pip_needed"
            ok=0
        fi
    fi

    log "checking LibreOffice (soffice) — HARD DEP..."
    local soffice_bin
    if soffice_bin="$(detect_soffice)"; then
        log "  OK: $soffice_bin"
    else
        err "  MISSING: LibreOffice (soffice) — REQUIRED"
        err "  Install: brew install --cask libreoffice    (macOS)"
        err "           sudo apt install libreoffice       (Ubuntu)"
        err "           https://www.libreoffice.org/download  (Windows)"
        ok=0
    fi

    log "checking PDF rasterizer (need one of: pdftoppm, ImageMagick, pdf2image)..."
    export PYTHON_BIN="${python_bin:-python3}"
    local rasterizer
    if rasterizer="$(detect_rasterizer)"; then
        log "  OK: $rasterizer"
    else
        err "  MISSING: no PDF rasterizer found"
        err "  Install one of:"
        err "    brew install poppler                    (macOS, preferred)"
        err "    sudo apt install poppler-utils          (Ubuntu, preferred)"
        err "    brew install imagemagick ghostscript    (macOS, fallback)"
        err "    pip install pdf2image                   (python fallback, still needs poppler)"
        ok=0
    fi

    log "checking optional: shellcheck..."
    if command -v shellcheck >/dev/null 2>&1; then
        log "  OK"
    else
        warn "  (optional) shellcheck not installed — used only for development"
    fi

    if [[ $ok -eq 1 ]]; then
        jq -n \
            --arg python "$python_bin" \
            --arg soffice "$soffice_bin" \
            --arg rasterizer "$rasterizer" \
            '{status:"ok", python:$python, soffice:$soffice, rasterizer:$rasterizer}'
        return 0
    else
        emit_error_json \
            "one or more required dependencies missing" \
            "MISSING_DEPS" \
            "Follow the install instructions printed above, then re-run doctor."
        return 1
    fi
}

_slug() {
    # basename without extension, lowercased, non-alnum → '-'
    local name
    name="$(basename "$1")"
    name="${name%.*}"
    printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed -E 's/-+/-/g; s/^-|-$//g'
}

_write_readme() {
    # Write the folder-level README.md that tells downstream readers which
    # markdown file to use. Called after extraction so the agent doesn't have
    # to author boilerplate. Idempotent — overwrites on rerun.
    local readme_path="$1"
    local slug="$2"
    local slide_count="$3"
    local input_basename="$4"

    cat > "$readme_path" <<EOF
# ${slug} — pptx-to-md output

Two markdown files, identical semantic content. Pick the right one for your use case.

| File | Use it when |
|---|---|
| **\`${slug}.md\`** (**default**) | Feeding the deck to an LLM, RAG pipeline, embeddings job, or any automation. Compact, no image dependencies, safe to pipe as text anywhere. |
| \`${slug}.with-images.md\` | You are a human doing a spot-check or audit and want to compare the synthesis against the original slide pixels. Contains plain-link references to every slide render and every embedded image. |

**Default rule: if in doubt, use \`${slug}.md\`.**

## What's in this folder

\`\`\`
${slug}/
├── README.md                              ← this file
├── ${slug}.md                             ← condensed, LLM-first
├── ${slug}.with-images.md                 ← detailed, with image links
└── ${slug}-assets/
    ├── slides/                            ← one PNG per slide (300 DPI)
    └── images/                            ← embedded images extracted from the pptx
\`\`\`

## Why two files?

The condensed \`.md\` is designed for LLM consumption: no image references means no risk of a vision-enabled reader auto-attaching PNGs and blowing the context window. The synthesis process at conversion time already extracted every piece of meaning from diagrams, charts, and screenshots into prose — a reader who never looks at an image can still answer any question about the deck.

The \`.with-images.md\` variant adds plain-link references (\`[Slide N — source render](…)\`, never \`![…](…)\` inline embeds) so a human auditor can click through to verify the synthesis against the source pixels.

Both files carry identical H1, executive summary, table of contents, per-slide content, tables, and speaker notes.

## Source

- Original: \`${input_basename}\`
- Slides: ${slide_count}
- Generated by: [powerpoint-to-md skill](https://github.com/) — pptx → md via MarkItDown + python-pptx (text) + LibreOffice + poppler (image render) + agent vision reasoning (synthesis).
EOF
}

cmd_extract() {
    local input="${1:-}"
    if [[ -z "$input" ]]; then
        emit_error_json "no input file provided" "MISSING_INPUT" "Usage: pptx2md.sh extract <input.pptx>"
        return 2
    fi
    if [[ ! -f "$input" ]]; then
        emit_error_json "input file not found: $input" "INPUT_NOT_FOUND" "Provide a path to an existing .pptx file"
        return 2
    fi
    local input_lower
    input_lower="$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')"
    case "$input_lower" in
        *.pptx) ;;
        *)
            emit_error_json "only .pptx files are supported (got: $input)" "UNSUPPORTED_FORMAT" "Convert to .pptx first (Keynote/Google Slides can export .pptx)"
            return 2
            ;;
    esac

    require_cmd jq || return 2

    # Resolve deps (hard-fail if missing).
    local python_bin soffice_bin rasterizer
    python_bin="$(detect_python)" || {
        emit_error_json "python3 not found" "MISSING_DEP" "Install Python 3.10+; run pptx2md.sh doctor for OS-specific instructions"
        return 2
    }
    soffice_bin="$(detect_soffice)" || {
        emit_error_json "LibreOffice (soffice) not found — required" "MISSING_LIBREOFFICE" "brew install --cask libreoffice (macOS) or apt install libreoffice (Ubuntu). See references/troubleshooting.md"
        return 2
    }
    export PYTHON_BIN="$python_bin"
    rasterizer="$(detect_rasterizer)" || {
        emit_error_json "no PDF rasterizer found (need pdftoppm, ImageMagick, or pdf2image)" "MISSING_RASTERIZER" "brew install poppler (macOS) or apt install poppler-utils (Ubuntu). See references/troubleshooting.md"
        return 2
    }

    if ! check_python_modules "$python_bin" >/dev/null; then
        local missing
        missing="$(check_python_modules "$python_bin" || true)"
        emit_error_json "python module(s) missing: $missing" "MISSING_PY_MODULES" "pip install $missing"
        return 2
    fi

    # Resolve paths.
    #
    # Output convention: everything for one deck lives in a single wrapping
    # folder named after the input (slugged). This keeps runs self-contained
    # and avoids scattering files next to the input:
    #
    #   <input_dir>/<slug>/
    #     ├── <slug>.md
    #     └── <slug>-assets/
    #         ├── slides/*.png
    #         └── images/*
    #
    local input_abs
    input_abs="$(cd "$(dirname "$input")" && pwd)/$(basename "$input")"
    local input_dir
    input_dir="$(dirname "$input_abs")"
    local slug
    slug="$(_slug "$input_abs")"
    if [[ -z "$slug" ]]; then
        slug="deck"
    fi

    local output_root="$input_dir/${slug}"
    local output_md="$output_root/${slug}.md"
    local output_md_with_images="$output_root/${slug}.with-images.md"
    local readme_md="$output_root/README.md"
    local assets_dir="$output_root/${slug}-assets"
    local slides_out="$assets_dir/slides"
    local images_out="$assets_dir/images"

    # Tmp workspace.
    local tmp_dir
    tmp_dir="$(mktemp -d -t "pptx2md-XXXXXX")"
    log "tmp dir: $tmp_dir"

    mkdir -p "$output_root" "$assets_dir" "$slides_out" "$images_out"

    # Track A: text extraction.
    log "extracting text (markitdown + python-pptx)..."
    if ! "$python_bin" "$SCRIPT_DIR/extract_text.py" \
            --input "$input_abs" \
            --tmp-dir "$tmp_dir" \
            --images-out "$images_out" \
            >&2; then
        emit_error_json "text extraction failed" "EXTRACT_TEXT_FAILED" "See stderr above. Check that the .pptx is not password-protected or corrupt."
        return 3
    fi

    if [[ ! -f "$tmp_dir/extract.json" ]]; then
        emit_error_json "extract.json not produced" "EXTRACT_TEXT_FAILED" "Internal error — extract_text.py did not write extract.json"
        return 3
    fi

    # Track B: slide rendering.
    log "rendering slides (soffice + $rasterizer)..."
    if ! SOFFICE_BIN="$soffice_bin" RASTERIZER="$rasterizer" PYTHON_BIN="$python_bin" \
            "$SCRIPT_DIR/render_slides.sh" "$input_abs" "$tmp_dir" "$slides_out" >&2; then
        emit_error_json "slide rendering failed" "RENDER_FAILED" "See stderr above. Try running 'pptx2md.sh doctor' to verify soffice and rasterizer."
        return 3
    fi

    # Compose slide + image lists from what actually landed on disk.
    local slide_count
    slide_count="$(find "$slides_out" -maxdepth 1 -name 'slide-*.png' -type f 2>/dev/null | wc -l | tr -d '[:space:]')"

    # Pre-write the folder-level README so the agent doesn't author boilerplate.
    _write_readme "$readme_md" "$slug" "$slide_count" "$(basename "$input_abs")"
    log "wrote $readme_md"

    # Manifest — this is what the calling agent parses.
    jq -n \
        --arg status "success" \
        --arg deck_name "$slug" \
        --arg input "$input_abs" \
        --arg output_root "$output_root" \
        --arg output_md "$output_md" \
        --arg output_md_with_images "$output_md_with_images" \
        --arg readme_md "$readme_md" \
        --arg assets_dir "$assets_dir" \
        --arg tmp_dir "$tmp_dir" \
        --arg extract_json "$tmp_dir/extract.json" \
        --arg slides_dir "$slides_out" \
        --arg images_dir "$images_out" \
        --arg synthesis_prompt "$SCRIPT_DIR/../references/slide-synthesis-prompt.md" \
        --arg template "$SCRIPT_DIR/../assets/deck-template.md" \
        --argjson slide_count "$slide_count" \
        '{
            status: $status,
            deck_name: $deck_name,
            input: $input,
            output_root: $output_root,
            output_md: $output_md,
            output_md_with_images: $output_md_with_images,
            readme_md: $readme_md,
            assets_dir: $assets_dir,
            tmp_dir: $tmp_dir,
            extract_json: $extract_json,
            slides_dir: $slides_dir,
            images_dir: $images_dir,
            slide_count: $slide_count,
            synthesis_prompt_ref: $synthesis_prompt,
            template_ref: $template,
            next_steps: [
                "Read extract_json for verbatim text, notes, tables, chart data",
                "Read every slide-*.png in slides_dir for visual intent",
                "Follow synthesis_prompt_ref and template_ref rules",
                "Write output_md_with_images first (detailed, with image links)",
                "Derive output_md from it by stripping [figure — ...] and [Slide N — source render] lines",
                "README.md is already written for you at readme_md",
                "Run: pptx2md.sh cleanup <tmp_dir>"
            ]
        }'
}

cmd_convert() {
    # convert = extract + explicit reminder to the calling agent that it must
    # write deck.md and then call cleanup. This script cannot write deck.md
    # itself — that requires the agent's vision reasoning over slide PNGs.
    #
    # convert therefore prints the same manifest as extract, but also emits
    # a stderr banner making the workflow explicit.
    local manifest
    if ! manifest="$(cmd_extract "$@")"; then
        echo "$manifest"
        return $?
    fi

    log ""
    log "=================================================================="
    log "  EXTRACTION COMPLETE — agent must now:"
    log "    1. read extract_json from the manifest"
    log "    2. read every slide-*.png in slides_dir"
    log "    3. write output_md following the synthesis rubric"
    log "    4. run: pptx2md.sh cleanup <tmp_dir>"
    log "=================================================================="

    echo "$manifest"
}

cmd_cleanup() {
    local tmp_dir="${1:-}"
    if [[ -z "$tmp_dir" ]]; then
        emit_error_json "no tmp dir provided" "MISSING_INPUT" "Usage: pptx2md.sh cleanup <tmp_dir>"
        return 2
    fi
    # Safety: only remove if it looks like our tmp dir.
    case "$tmp_dir" in
        */pptx2md-*)
            if [[ -d "$tmp_dir" ]]; then
                rm -rf "$tmp_dir"
                log "cleaned up $tmp_dir"
                jq -n --arg tmp_dir "$tmp_dir" '{status:"success", cleaned:$tmp_dir}'
            else
                log "tmp dir already gone: $tmp_dir"
                jq -n --arg tmp_dir "$tmp_dir" '{status:"success", note:"already absent", tmp_dir:$tmp_dir}'
            fi
            ;;
        *)
            emit_error_json "refusing to remove path that does not look like a pptx2md tmp dir: $tmp_dir" "UNSAFE_PATH" "Only paths matching */pptx2md-* are cleaned up"
            return 2
            ;;
    esac
}

usage() {
    cat <<'EOF' >&2
Usage:
  pptx2md.sh doctor
  pptx2md.sh extract  <input.pptx>
  pptx2md.sh convert  <input.pptx>
  pptx2md.sh cleanup  <tmp_dir>

Commands:
  doctor    Verify dependencies. Prints JSON status to stdout, install fixes to stderr.
  extract   Run both text and image extraction. Prints a JSON manifest to stdout.
            Durable artifacts land in ./{deck-name}-assets/ next to the input.
            The extract.json manifest lives in a tmp dir — call cleanup when done.
  convert   Same as extract, plus a stderr banner reminding the agent of next steps.
  cleanup   Delete a tmp dir returned by extract/convert.

See SKILL.md for the full workflow the calling agent must follow.
EOF
}

main() {
    local cmd="${1:-}"
    if [[ -z "$cmd" ]]; then
        usage
        return 2
    fi
    shift
    case "$cmd" in
        doctor)  cmd_doctor "$@" ;;
        extract) cmd_extract "$@" ;;
        convert) cmd_convert "$@" ;;
        cleanup) cmd_cleanup "$@" ;;
        -h|--help|help) usage; return 0 ;;
        *)
            err "unknown command: $cmd"
            usage
            return 2
            ;;
    esac
}

main "$@"
