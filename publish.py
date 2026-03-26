#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Publish a ForgeCAD design to kostard.github.io.

Copies the .forge.js file, adds a card to the homepage, commits and pushes.

Usage:
    ./publish.py path/to/design.forge.js "Title" "Description"
"""

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

BASE_URL = "https://kostard.github.io"
REPO_DIR = Path(__file__).resolve().parent
DESIGNS_DIR = REPO_DIR / "forgecad-designs"
INDEX = REPO_DIR / "index.html"


def slug_to_html_id(slug: str) -> str:
    return slug.replace("_", "-").lower()


def build_card(filename: str, html_id: str, title: str, desc: str) -> str:
    return f"""
    <div class="forge-card">
      <div class="forge-preview" id="{html_id}-preview">
        <iframe
          class="embed-frame"
          src="{BASE_URL}/ForgeCAD/?url={BASE_URL}/forgecad-designs/{filename}&embed=1"
          loading="lazy"
          title="{title} preview"
          sandbox="allow-scripts allow-same-origin"
        ></iframe>
      </div>
      <div class="forge-info">
        <h3>{title}</h3>
        <p>{desc}</p>
        <div class="forge-actions">
          <a class="forge-btn primary"
             href="{BASE_URL}/ForgeCAD/?url={BASE_URL}/forgecad-designs/{filename}"
             target="_blank">
            Open in ForgeCAD
          </a>
          <button class="forge-btn source-toggle" onclick="toggleSource('{html_id}-source')">
            &lt;/&gt; Source
          </button>
        </div>
        <pre class="source-code" id="{html_id}-source"><code class="language-javascript"></code></pre>
      </div>
    </div>"""


def insert_card(html: str, card: str) -> str:
    marker = '  </div>\n</section>\n\n<section class="section" id="blog">'
    if marker not in html:
        sys.exit("Error: Could not find forge-grid insertion point in index.html")
    return html.replace(marker, card + "\n\n" + marker, 1)


def git(*args: str) -> None:
    subprocess.run(["git", "-C", str(REPO_DIR), *args], check=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("file", type=Path, help="Path to .forge.js file")
    parser.add_argument("title", help="Display title for the design")
    parser.add_argument("description", help="Short description")
    args = parser.parse_args()

    src: Path = args.file.resolve()
    if not src.exists():
        sys.exit(f"Error: File not found: {src}")
    if not src.name.endswith(".forge.js"):
        sys.exit("Error: File must end in .forge.js")

    filename = src.name
    slug = filename.removesuffix(".forge.js")
    html_id = slug_to_html_id(slug)
    dest = DESIGNS_DIR / filename

    action = "Updating" if dest.exists() else "Publishing"
    print(f"{action}: {filename}")

    shutil.copy2(src, dest)

    html = INDEX.read_text()
    if f"forgecad-designs/{filename}" in html:
        print("Card already exists — updating file only.")
    else:
        card = build_card(filename, html_id, args.title, args.description)
        html = insert_card(html, card)
        INDEX.write_text(html)
        print("Card added to index.html")

    git("add", f"forgecad-designs/{filename}", "index.html")
    git("commit", "-m", f"Publish ForgeCAD design: {args.title}")
    git("push", "origin", "master")

    print()
    print(f"Published! View at: {BASE_URL}/#forgecad-designs")
    print(f"Open in ForgeCAD: {BASE_URL}/ForgeCAD/?url={BASE_URL}/forgecad-designs/{filename}")


if __name__ == "__main__":
    main()
