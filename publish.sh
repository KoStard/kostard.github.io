#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DESIGNS_DIR="$REPO_DIR/forgecad-designs"
INDEX="$REPO_DIR/index.html"
BASE_URL="https://kostard.github.io"

usage() {
  echo "Usage: $0 <path/to/design.forge.js> \"Title\" \"Description\""
  echo ""
  echo "Copies the .forge.js file into the site, adds a card to the homepage,"
  echo "and commits + pushes."
  echo ""
  echo "Example:"
  echo "  $0 ~/Projects/CAD/my_bracket.forge.js \"Cable Bracket\" \"Parametric cable bracket with adjustable width\""
  exit 1
}

[[ $# -lt 3 ]] && usage

SRC_FILE="$1"
TITLE="$2"
DESC="$3"

# Validate input
[[ ! -f "$SRC_FILE" ]] && echo "Error: File not found: $SRC_FILE" && exit 1
[[ "$SRC_FILE" != *.forge.js ]] && echo "Error: File must end in .forge.js" && exit 1

FILENAME="$(basename "$SRC_FILE")"
SLUG="${FILENAME%.forge.js}"
# Sanitize slug for use as HTML id
HTML_ID="$(echo "$SLUG" | tr '_' '-' | tr '[:upper:]' '[:lower:]')"
DEST="$DESIGNS_DIR/$FILENAME"

if [[ -f "$DEST" ]]; then
  echo "Updating existing design: $FILENAME"
else
  echo "Publishing new design: $FILENAME"
fi

# Copy the file
cp "$SRC_FILE" "$DEST"

# Check if a card already exists for this file
if grep -q "forgecad-designs/$FILENAME" "$INDEX"; then
  echo "Card already exists in index.html — updating file only."
else
  # Build the card HTML
  CARD=$(cat <<CARD_EOF

    <div class="forge-card">
      <div class="forge-preview" id="${HTML_ID}-preview">
        <iframe
          class="embed-frame"
          src="${BASE_URL}/ForgeCAD/?url=${BASE_URL}/forgecad-designs/${FILENAME}&embed=1"
          loading="lazy"
          title="${TITLE} preview"
          sandbox="allow-scripts allow-same-origin"
        ></iframe>
      </div>
      <div class="forge-info">
        <h3>${TITLE}</h3>
        <p>${DESC}</p>
        <div class="forge-actions">
          <a class="forge-btn primary"
             href="${BASE_URL}/ForgeCAD/?url=${BASE_URL}/forgecad-designs/${FILENAME}"
             target="_blank">
            Open in ForgeCAD
          </a>
          <button class="forge-btn source-toggle" onclick="toggleSource('${HTML_ID}-source')">
            &lt;/&gt; Source
          </button>
        </div>
        <pre class="source-code" id="${HTML_ID}-source"><code class="language-javascript"></code></pre>
      </div>
    </div>
CARD_EOF
)

  # Insert the card before the closing </div></section> of the forge-grid
  TMPFILE="$(mktemp)"
  python3 -c "
import sys
with open('$INDEX', 'r') as f:
    content = f.read()

marker = '  </div>\n</section>\n\n<section class=\"section\" id=\"blog\">'
card = '''$CARD'''

if marker not in content:
    print('Error: Could not find insertion point in index.html', file=sys.stderr)
    sys.exit(1)

content = content.replace(marker, card + '\n\n  </div>\n</section>\n\n<section class=\"section\" id=\"blog\">', 1)

with open('$TMPFILE', 'w') as f:
    f.write(content)
"
  mv "$TMPFILE" "$INDEX"

  echo "Card added to index.html"
fi

# Update the toggleSource function to handle the new file
# Check if the source toggle already has a mapping for this file, otherwise
# we need to make toggleSource generic. Let's update it to derive the URL from the id.

# Check if toggleSource is already generic (uses id-based URL mapping)
if ! grep -q "sourceUrls" "$INDEX"; then
  # Replace the hardcoded toggleSource with a generic one
  TMPFILE="$(mktemp)"
  python3 -c "
import re, sys

with open('$INDEX', 'r') as f:
    content = f.read()

old_fn = '''const sourceCache = {};
async function toggleSource(id) {
  const pre = document.getElementById(id);
  if (pre.classList.contains('open')) {
    pre.classList.remove('open');
    return;
  }
  const codeEl = pre.querySelector('code');
  if (!sourceCache[id]) {
    const url = '/forgecad-designs/ams_lite_adapter.forge.js';
    try {
      const res = await fetch(url);
      sourceCache[id] = await res.text();
    } catch {
      sourceCache[id] = '// Failed to load source';
    }
  }
  codeEl.textContent = sourceCache[id];
  hljs.highlightElement(codeEl);
  pre.classList.add('open');
}'''

new_fn = '''const sourceCache = {};
async function toggleSource(id) {
  const pre = document.getElementById(id);
  if (pre.classList.contains('open')) {
    pre.classList.remove('open');
    return;
  }
  const codeEl = pre.querySelector('code');
  if (!sourceCache[id]) {
    // Derive filename from the id: \"foo-bar-source\" -> \"foo_bar.forge.js\"
    const slug = id.replace(/-source\$/, '').replace(/-/g, '_');
    const url = '/forgecad-designs/' + slug + '.forge.js';
    try {
      const res = await fetch(url);
      if (!res.ok) throw new Error(res.statusText);
      sourceCache[id] = await res.text();
    } catch {
      sourceCache[id] = '// Failed to load source';
    }
  }
  codeEl.textContent = sourceCache[id];
  hljs.highlightElement(codeEl);
  pre.classList.add('open');
}'''

content = content.replace(old_fn, new_fn)

with open('$TMPFILE', 'w') as f:
    f.write(content)
" 2>&1
  mv "$TMPFILE" "$INDEX"
  echo "Updated toggleSource to be generic"
fi

# Commit and push
cd "$REPO_DIR"
git add "forgecad-designs/$FILENAME" index.html
git commit -m "Publish ForgeCAD design: $TITLE

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
git push origin master

echo ""
echo "Published! View at: ${BASE_URL}/#forgecad-designs"
echo "Open in ForgeCAD: ${BASE_URL}/ForgeCAD/?url=${BASE_URL}/forgecad-designs/${FILENAME}"
