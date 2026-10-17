#!/bin/bash
# Builds Resources/Assets.xcassets from the raw Figma exports.
set -euo pipefail
cd "$(dirname "$0")/.."

ASSETS="Resources/Assets.xcassets"
mkdir -p "$ASSETS"

cat > "$ASSETS/Contents.json" <<'EOF'
{
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF

make_vector_imageset () {
  local name="$1" file="$2"
  local dir="$ASSETS/$name.imageset"
  mkdir -p "$dir"
  cp "Resources/Icons/$file" "$dir/"
  cat > "$dir/Contents.json" <<EOF
{
  "images" : [
    { "filename" : "$file", "idiom" : "universal" }
  ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : {
    "preserves-vector-representation" : true,
    "template-rendering-intent" : "original"
  }
}
EOF
}

make_raster_imageset () {
  local name="$1" file="$2"
  local dir="$ASSETS/$name.imageset"
  mkdir -p "$dir"
  cp "Resources/Images/$file" "$dir/"
  cat > "$dir/Contents.json" <<EOF
{
  "images" : [
    { "filename" : "$file", "idiom" : "universal" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF
}

make_vector_imageset "icon-search"      "icon-search.svg"
make_vector_imageset "icon-dots"        "icon-dots.svg"
make_vector_imageset "icon-trash"       "icon-trash.svg"
make_vector_imageset "icon-plus"        "icon-plus.svg"
make_vector_imageset "icon-arrows-sort" "icon-arrows-sort.svg"
make_vector_imageset "icon-browser"     "icon-browser.svg"
make_vector_imageset "icon-settings"    "icon-settings.svg"
make_vector_imageset "icon-play"        "icon-play.svg"
make_vector_imageset "icon-folder"      "icon-folder.svg"
make_vector_imageset "icon-link"        "icon-link.svg"

make_raster_imageset "noise-texture"    "noise-texture.png"
make_raster_imageset "sample-thumbnail" "sample-thumbnail.png"

echo "Asset catalog built at $ASSETS"
