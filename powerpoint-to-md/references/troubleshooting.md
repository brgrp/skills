# Troubleshooting

## Quick check

Always start with:

```bash
./powerpoint-to-md/scripts/pptx2md.sh doctor
```

It prints per-tool status to stderr and a JSON verdict to stdout. Non-zero exit means a hard dependency is missing.

---

## Hard dependency: LibreOffice (`soffice`)

`soffice` is REQUIRED. The skill fails fast without it.

### Install

**macOS (Homebrew):**
```bash
brew install --cask libreoffice
```
After install, `soffice` may not be on `PATH`. The doctor checks `/Applications/LibreOffice.app/Contents/MacOS/soffice` too, but if you want it on `PATH`:
```bash
sudo ln -s /Applications/LibreOffice.app/Contents/MacOS/soffice /usr/local/bin/soffice
```

**Ubuntu / Debian:**
```bash
sudo apt update
sudo apt install libreoffice
```

**Fedora / RHEL:**
```bash
sudo dnf install libreoffice
```

**Windows:**
Download the installer from https://www.libreoffice.org/download and select "Add to PATH" during install. Alternative via winget:
```powershell
winget install TheDocumentFoundation.LibreOffice
```

### Common soffice errors

**"soffice: command not found"**
- macOS: `soffice` isn't symlinked. Run the symlink command above or export `PATH`.
- Linux: package not installed. Run the install command.

**"cannot open display" / "Fatal Error: Application cannot be started"**
- soffice is trying to open a GUI. The skill uses `--headless` — if you still get this, an existing LibreOffice instance is running interactively and blocking the profile. Close it, or rely on the skill's per-run `-env:UserInstallation` profile which should avoid the clash.

**"source file could not be loaded"**
- The .pptx is corrupt or password-protected. Open it in real PowerPoint / LibreOffice first, save-as a fresh .pptx, and retry.

---

## PDF rasterizer (one of three)

The skill picks the first that's available.

### 1. `pdftoppm` (poppler) — preferred

**macOS:** `brew install poppler`
**Ubuntu / Debian:** `sudo apt install poppler-utils`
**Windows:** poppler is not a first-class Windows package. Use ImageMagick or `pdf2image` on Windows.

### 2. ImageMagick + Ghostscript — fallback

**macOS:** `brew install imagemagick ghostscript`
**Ubuntu / Debian:** `sudo apt install imagemagick ghostscript`
**Windows:** `winget install ImageMagick.ImageMagick GnuGPL.Ghostscript`

**Common ImageMagick error: `not authorized 'PDF' @ error/constitute.c/ReadImage`**

By default, ImageMagick policy disables PDF handling (CVE-2018-16509 mitigation). Fix:

```bash
# Find the policy file
find /etc /opt /usr -name policy.xml 2>/dev/null | grep -i ImageMagick
# Common paths:
#   /etc/ImageMagick-6/policy.xml
#   /etc/ImageMagick-7/policy.xml
#   /opt/homebrew/etc/ImageMagick-7/policy.xml
```

Edit the file. Find the line:
```xml
<policy domain="coder" rights="none" pattern="PDF" />
```
Change to:
```xml
<policy domain="coder" rights="read|write" pattern="PDF" />
```

If you don't want to modify system policy, install poppler instead (preferred anyway).

### 3. `pdf2image` (Python) — last resort

```bash
pip install pdf2image
```

`pdf2image` is a Python wrapper around poppler — it needs poppler's `pdftoppm` on Windows via a portable poppler zip. On macOS/Linux it needs `brew install poppler` / `apt install poppler-utils` anyway, so prefer using `pdftoppm` directly.

---

## Python modules

Required:

```bash
pip install 'markitdown[pptx]' python-pptx
```

Minimum Python: 3.10. Check with `python3 --version`.

**"ModuleNotFoundError: No module named 'markitdown'"** — you installed to a different interpreter than the one on `PATH`. Try `python3 -m pip install 'markitdown[pptx]' python-pptx`.

**"ModuleNotFoundError: No module named 'pptx'"** — the pip package is `python-pptx`, not `pptx`. Reinstall: `pip install python-pptx`.

**MarkItDown produces empty output** — some pptx variants (older `.ppt`, non-standard XML) trip MarkItDown. The pipeline continues on python-pptx only in that case (there's a `WARN: markitdown …` line in stderr). You still get a full `extract.json` — MarkItDown adds structural markdown, python-pptx supplies everything essential.

---

## Input file issues

### Password-protected `.pptx`
Not supported in v1. Open the file, remove the password (File → Info → Protect Presentation → Encrypt with Password → clear), save, retry.

### `.ppt` (old binary format)
Not supported. Open in PowerPoint or LibreOffice and Save As `.pptx` first.

### Keynote `.key` / Google Slides
Not supported. Export to `.pptx` from the source app first.

### Corrupt `.pptx`
Both soffice and python-pptx will complain in different ways. The clearest fix: open in real PowerPoint, save-as a new `.pptx`, retry.

### Very large decks (100+ slides)
Works but slow — soffice PDF conversion is single-threaded, and each rasterizer runs sequentially. Expect ~2–4 seconds per slide end-to-end on a modern laptop. If the machine is memory-constrained (<8 GB), ImageMagick at 300 DPI on a big deck can OOM; prefer pdftoppm.

---

## Output surprises

### `deck.md` missing images
Check `deck-assets/slides/` and `deck-assets/images/` next to `deck.md`. If empty, the agent likely wrote paths but the extractor failed silently — re-run with `pptx2md.sh doctor` and inspect stderr.

### Slide numbering doesn't match PowerPoint
The skill uses 1-based indexing of slides IN THE FILE, ignoring hidden-slide flags. If your deck has hidden slides they're still numbered 1..N.

### PNG names are `slide-1.png` not `slide-01.png`
Newer poppler zero-pads to 2 digits automatically. Older versions do not. The `render_slides.sh` script normalizes to `slide-NN.png` after rendering; if you see un-padded names something failed halfway. Re-run.

---

## Diagnosing a failed run

The manifest returns `status: "error"` with a `code`. Map:

| Code | Meaning | Fix |
|---|---|---|
| `MISSING_INPUT` | No pptx path passed | Pass the .pptx path |
| `INPUT_NOT_FOUND` | Path doesn't exist | Check spelling / cwd |
| `UNSUPPORTED_FORMAT` | Not a .pptx | Convert to .pptx |
| `MISSING_DEP` | Python/jq missing | See doctor output |
| `MISSING_LIBREOFFICE` | soffice not found | Install LibreOffice |
| `MISSING_RASTERIZER` | No pdftoppm/magick/pdf2image | Install poppler |
| `MISSING_PY_MODULES` | markitdown or python-pptx missing | `pip install` |
| `EXTRACT_TEXT_FAILED` | Track A failed | Check stderr; likely corrupt pptx |
| `RENDER_FAILED` | Track B failed | Check stderr; likely soffice or policy issue |
| `UNSAFE_PATH` | cleanup refused | Path didn't match `pptx2md-*` template |

All hard errors surface both to stderr (human-readable) and stdout (JSON with `code` and `solution`).
