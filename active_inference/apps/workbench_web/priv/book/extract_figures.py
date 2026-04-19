#!/usr/bin/env python3
"""
Extract figure page images from the Parr/Pezzulo/Friston 2022 PDF into
`priv/static/book/figures/fig_<N>_<M>.png`.

Approach: pypdfium2 renders the page that contains each figure and we save
it as PNG at 150 DPI.  Chapter → approximate page offsets are derived from
the PDF's own TOC; when a figure number is given we scan pages nearby for
the `Figure N.M` caption and render the matching page.

Run once offline:

    python apps/workbench_web/priv/book/extract_figures.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# Anchors: approximate chapter-to-PDF-page mapping (1-indexed PDF pages).
# Derived from the TOC and the Chapters.txt_lines ranges.
CHAPTER_PAGES = {
    0: (1, 30),       # preface + front matter
    1: (31, 52),      # Ch 1 Overview
    2: (53, 80),      # Ch 2 Low Road
    3: (81, 106),     # Ch 3 High Road
    4: (107, 138),    # Ch 4 Generative Models
    5: (139, 170),    # Ch 5 Message Passing
    6: (171, 200),    # Ch 6 Recipe
    7: (171, 210),    # Ch 7 Discrete
    8: (211, 238),    # Ch 8 Continuous
    9: (239, 264),    # Ch 9 Analysis
    10: (265, 310),   # Ch 10 Unified
}

# Figures referenced from Sessions.figures; extracted if found.
FIGURES = [
    "1.1", "2.1", "2.2", "3.1", "4.1", "4.2", "4.5",
    "5.1", "5.5", "6.1", "6.2", "7.1", "7.2", "7.5",
    "8.1", "8.3", "9.1", "9.2", "10.1"
]


def find_pdf() -> Path:
    here = Path(__file__).resolve()
    search = [here.parent] + list(here.parents)
    for up in search:
        for name in ("book_9780262369978.pdf", "book.pdf"):
            candidate = up / name
            if candidate.exists():
                return candidate
    raise FileNotFoundError(
        "book_9780262369978.pdf not found. See BOOK_SOURCES.md at the repo "
        "root for how to supply the Parr/Pezzulo/Friston (2022) PDF locally. "
        "The book is CC BY-NC-ND from MIT Press; local copies are gitignored."
    )


def out_dir() -> Path:
    here = Path(__file__).resolve()
    # apps/workbench_web/priv/book/ → apps/workbench_web/priv/static/book/figures
    return here.parent.parent / "static" / "book" / "figures"


def main() -> None:
    import fitz  # PyMuPDF

    pdf_path = find_pdf()
    out = out_dir()
    out.mkdir(parents=True, exist_ok=True)
    print(f"PDF: {pdf_path}")
    print(f"OUT: {out}")

    doc = fitz.open(pdf_path)
    total = doc.page_count
    print(f"Pages: {total}")

    matrix = fitz.Matrix(150 / 72, 150 / 72)  # 150 DPI

    # One pre-pass: find every "Figure N.M" caption in the whole PDF.
    print("Scanning PDF for figure captions…")
    figure_pages: dict[str, int] = {}
    scan_re = re.compile(r"\bFigure\s+(\d{1,2}\.\d{1,2})\b")
    for pnum in range(total):
        text = doc[pnum].get_text("text")
        for m in scan_re.finditer(text):
            k = m.group(1)
            if k not in figure_pages:
                figure_pages[k] = pnum

    print(f"Found {len(figure_pages)} distinct figure captions.")

    for fig_num in FIGURES:
        pnum = figure_pages.get(fig_num)
        if pnum is None:
            print(f"  fig {fig_num}: no caption anywhere in PDF")
            continue

        page = doc[pnum]
        pix = page.get_pixmap(matrix=matrix, alpha=False)
        fname = out / f"fig_{fig_num.replace('.', '_')}.png"
        pix.save(str(fname))
        print(f"  fig {fig_num}: page {pnum + 1} → {fname.name} ({pix.width}x{pix.height})")

    doc.close()
    print("Done.")


if __name__ == "__main__":
    main()
