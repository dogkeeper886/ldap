#!/usr/bin/env bash
# Render diagram SVG sources to PNG. SVG is the source of truth; edit it, then re-run.
# Requires: rsvg-convert (librsvg).
set -euo pipefail
cd "$(dirname "$0")"
for svg in *.svg; do
  rsvg-convert -z 2 -o "${svg%.svg}.png" "$svg"
  echo "rendered ${svg%.svg}.png"
done
