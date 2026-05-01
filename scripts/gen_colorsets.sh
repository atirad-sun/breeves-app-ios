#!/bin/bash
# Generates colorset folders for all design tokens. Idempotent.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS="$ROOT/Packages/DesignSystem/Sources/DesignSystem/Resources/Colors.xcassets"

# name|darkRGBA|lightRGBA  (alpha in 0..1, RGB in 0..255 hex)
COLORS=(
  "BgCanvas|0x00,0x00,0x00,1.0|0xF5,0xF2,0xEC,1.0"
  "BgElevated1|0x0A,0x0A,0x0B,1.0|0xFF,0xFF,0xFF,1.0"
  "BgElevated2|0x13,0x13,0x16,1.0|0xF0,0xED,0xE6,1.0"
  "BgScrim|0x00,0x00,0x00,0.55|0x00,0x00,0x00,0.40"
  "HairlineFaint|0xFF,0xFF,0xFF,0.06|0x0A,0x0A,0x0B,0.04"
  "HairlineStandard|0xFF,0xFF,0xFF,0.10|0x0A,0x0A,0x0B,0.10"
  "HairlineStrong|0xFF,0xFF,0xFF,0.18|0x0A,0x0A,0x0B,0.18"
  "TextPrimary|0xF5,0xF2,0xEC,1.0|0x0A,0x0A,0x0B,1.0"
  "TextSecondary|0xA8,0xA3,0x9A,1.0|0x4B,0x48,0x42,1.0"
  "TextTertiary|0x6E,0x6A,0x63,1.0|0x8A,0x86,0x80,1.0"
  "TextInverse|0x0A,0x0A,0x0B,1.0|0xF5,0xF2,0xEC,1.0"
  "AccentPrimary|0xC8,0xA4,0x5C,1.0|0x8A,0x6F,0x3D,1.0"
  "AccentMuted|0x8A,0x6F,0x3D,1.0|0xB8,0x96,0x6A,1.0"
  "Topic1|0xC8,0xA4,0x5C,1.0|0x8A,0x6F,0x3D,1.0"
  "Topic2|0x7A,0x9E,0x9F,1.0|0x4A,0x7E,0x7F,1.0"
  "Topic3|0xB4,0x65,0x4A,1.0|0x8B,0x3E,0x2A,1.0"
  "StateRead|0xF5,0xF2,0xEC,0.32|0x0A,0x0A,0x0B,0.28"
  "StateSuccess|0x6B,0x8E,0x5A,1.0|0x4B,0x6E,0x3A,1.0"
  "StateDanger|0xB4,0x55,0x4A,1.0|0x8B,0x2A,0x1A,1.0"
)

for entry in "${COLORS[@]}"; do
  IFS='|' read -r name darkRGBA lightRGBA <<< "$entry"
  IFS=',' read -r dr dg db da <<< "$darkRGBA"
  IFS=',' read -r lr lg lb la <<< "$lightRGBA"
  dir="$ASSETS/${name}.colorset"
  mkdir -p "$dir"
  cat > "$dir/Contents.json" <<EOF
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "${la}",
          "blue" : "${lb}",
          "green" : "${lg}",
          "red" : "${lr}"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        { "appearance" : "luminosity", "value" : "dark" }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "${da}",
          "blue" : "${db}",
          "green" : "${dg}",
          "red" : "${dr}"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
done

echo "Generated ${#COLORS[@]} colorsets at $ASSETS"
