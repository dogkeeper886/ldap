#!/usr/bin/env bash
# Render the README diagram sources (SVG → PNG). The SVG is the source of truth;
# edit the .svg, then re-run this script to regenerate the committed .png.
# Requires: rsvg-convert (librsvg).
set -euo pipefail
cd "$(dirname "$0")"
for svg in *.svg; do
  png="${svg%.svg}.png"
  rsvg-convert -z 2 -o "$png" "$svg"
  echo "rendered $png"
done
