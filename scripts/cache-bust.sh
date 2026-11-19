#!/usr/bin/env bash
# Append a content hash (?v=...) to local asset URLs in the HTML and CSS files.
#
# Run before deploying. Assets whose content changed get a new URL, so browsers
# cannot serve a stale cached copy. Safe to run repeatedly.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
extensions='\.(css|svg|png|woff2|ico)$'

# Escape a string for use in a sed regex.
escape() { printf '%s' "$1" | sed -e 's/[][\.*^$|(){}+?\/&]/\\&/g'; }

# Print the content hash of a local asset referenced from a file in $2, or
# nothing if the reference is remote, not a known asset type, or missing.
asset_hash() {
  local ref="$1" base="$2" target
  [[ -z "$ref" || "$ref" =~ ^(https?:|//|data:|mailto:) ]] && return 0
  [[ "${ref,,}" =~ $extensions ]] || return 0
  if [[ "$ref" == /* ]]; then target="$root$ref"; else target="$base/$ref"; fi
  [[ -f "$target" ]] || return 0
  sha256sum "$target" | cut -c1-10
}

# CSS first: its own hash must reflect the stamped font URLs.
for stylesheet in "$root"/css/*.css; do
  base="$(dirname "$stylesheet")"
  while IFS= read -r ref; do
    hash="$(asset_hash "$ref" "$base")"
    [[ -n "$hash" ]] || continue
    sed -E -i "s/(url\(['\"]?$(escape "$ref"))(\?v=[0-9a-f]+)?(['\")])/\1?v=${hash}\3/g" "$stylesheet"
  done < <(grep -oE "url\(['\"]?[^)'\"?#]+" "$stylesheet" | sed -E "s/^url\(['\"]?//" | sort -u)
done

for page in "$root"/*.html; do
  while IFS= read -r ref; do
    hash="$(asset_hash "$ref" "$root")"
    [[ -n "$hash" ]] || continue
    sed -E -i "s/((src|href)=\"$(escape "$ref"))(\?v=[0-9a-f]+)?\"/\1?v=${hash}\"/g" "$page"
  done < <(grep -oE '(src|href)="[^"?#]+' "$page" | sed -E 's/^(src|href)="//' | sort -u)
done
