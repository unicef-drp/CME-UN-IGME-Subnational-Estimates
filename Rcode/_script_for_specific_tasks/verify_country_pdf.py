from __future__ import annotations

import json
import sys
from pathlib import Path

import pymupdf as fitz
from PIL import Image, ImageDraw, ImageOps


if len(sys.argv) != 3:
    raise SystemExit("Usage: verify_country_pdf.py REPORT.pdf OUTPUT_DIR")

pdf_path = Path(sys.argv[1]).resolve()
review_dir = Path(sys.argv[2]).resolve()
page_dir = review_dir / "pages"
sheet_dir = review_dir / "contact_sheets"
page_dir.mkdir(parents=True, exist_ok=True)
sheet_dir.mkdir(parents=True, exist_ok=True)

document = fitz.open(pdf_path)
page_rows = []
thumbnail_paths = []
zoom = 120 / 72

for page_index, page in enumerate(document):
    page_number = page_index + 1
    pixmap = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), alpha=False)
    page_path = page_dir / f"page_{page_number:03d}.png"
    pixmap.save(page_path)

    image = Image.open(page_path).convert("L")
    histogram = image.histogram()
    white_pixels = sum(histogram[251:])
    pixel_count = image.width * image.height
    white_ratio = white_pixels / pixel_count
    text_chars = len(page.get_text("text").strip())
    page_rows.append(
        {
            "page": page_number,
            "width_points": round(page.rect.width, 3),
            "height_points": round(page.rect.height, 3),
            "text_chars": text_chars,
            "white_ratio": round(white_ratio, 6),
            "blank_flag": white_ratio > 0.995,
        }
    )

    thumbnail = Image.open(page_path).convert("RGB")
    thumbnail.thumbnail((280, 396), Image.Resampling.LANCZOS)
    framed = Image.new("RGB", (300, 430), "white")
    draw = ImageDraw.Draw(framed)
    draw.text((10, 5), f"Page {page_number}", fill="black")
    framed.paste(thumbnail, ((300 - thumbnail.width) // 2, 28))
    framed = ImageOps.expand(framed, border=1, fill="#808080")
    thumbnail_path = review_dir / f"thumb_{page_number:03d}.png"
    framed.save(thumbnail_path)
    thumbnail_paths.append(thumbnail_path)

pages_per_sheet = 12
columns = 4
rows = 3
sheet_paths = []
for start in range(0, len(thumbnail_paths), pages_per_sheet):
    sheet_number = start // pages_per_sheet + 1
    sheet = Image.new("RGB", (columns * 302, rows * 432), "#d8d8d8")
    for offset, thumbnail_path in enumerate(
        thumbnail_paths[start : start + pages_per_sheet]
    ):
        thumbnail = Image.open(thumbnail_path).convert("RGB")
        x = (offset % columns) * 302
        y = (offset // columns) * 432
        sheet.paste(thumbnail, (x, y))
    sheet_path = sheet_dir / f"contact_sheet_{sheet_number:02d}.png"
    sheet.save(sheet_path)
    sheet_paths.append(str(sheet_path))

summary = {
    "pdf": str(pdf_path),
    "page_count": len(document),
    "page_size_points": sorted(
        {f"{row['width_points']}x{row['height_points']}" for row in page_rows}
    ),
    "blank_pages": [row["page"] for row in page_rows if row["blank_flag"]],
    "min_text_chars": min(row["text_chars"] for row in page_rows),
    "max_white_ratio": max(row["white_ratio"] for row in page_rows),
    "contact_sheets": sheet_paths,
    "pages": page_rows,
}
(review_dir / "pdf_render_summary.json").write_text(
    json.dumps(summary, indent=2), encoding="utf-8"
)
print(json.dumps({key: summary[key] for key in summary if key != "pages"}, indent=2))
