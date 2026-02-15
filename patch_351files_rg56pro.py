#!/usr/bin/env python3
"""Patch 351Files source to add DEVICE_RG56PRO support (1280x720)."""

import re

# --- Patch src/def.h ---

with open("src/def.h") as f:
    defh = f.read()

# 1. In button mapping sections, add RG56PRO wherever RG503 appears.
#    These are lines like:  #elif defined(DEVICE_RG503) || defined(DEVICE_...)
#    We add || defined(DEVICE_RG56PRO) to each.
defh = defh.replace(
    "defined(DEVICE_RG503)",
    "defined(DEVICE_RG503) || defined(DEVICE_RG56PRO)"
)

# 2. The above also added RG56PRO to the screen parameters block for RG503.
#    Now insert a separate RG56PRO screen block BEFORE the combined RG503 line
#    so RG56PRO gets its own resolution and the #elif for RG503 is never reached.
rg56pro_screen_block = """\
#elif defined(DEVICE_RG56PRO)
   #define SCREEN_WIDTH             1280
   #define SCREEN_HEIGHT            720
   #define HARDWARE_ACCELERATION    0
   #define FULLSCREEN               1
   #define FONT_NAME                "NotoSans-Regular.ttf"
   #define FONT_NAME_MONO           "NotoSansMono-Regular.ttf"
   #define FONT_SIZE                26
   #define LINE_HEIGHT              40
   #define ICON_SIZE                32
   #define MARGIN_X                 14
   #define KEYBOARD_MARGIN          10
   #define KEYBOARD_KEY_SPACING     5
   #define KEYBOARD_SYMBOL_SIZE     30
"""

# Find the #elif line for RG503 screen params (contains SCREEN_WIDTH on a nearby line)
# and insert our block before it. We match the first occurrence of the combined line
# (which is in the screen parameters section).
# Pattern: #elif defined(DEVICE_RG503) || defined(DEVICE_RG56PRO)\n   #define SCREEN_WIDTH
defh = defh.replace(
    "#elif defined(DEVICE_RG503) || defined(DEVICE_RG56PRO)\n   #define SCREEN_WIDTH",
    rg56pro_screen_block + "#elif defined(DEVICE_RG503)\n   #define SCREEN_WIDTH"
)

with open("src/def.h", "w") as f:
    f.write(defh)

# --- Patch build_RG351.sh ---
# Add RG56PRO to the conditional that triggers dual-build (/roms and /roms2)

with open("build_RG351.sh") as f:
    buildsh = f.read()

# Target the specific conditional line (only occurrence with "RG503" ]]; then)
buildsh = buildsh.replace(
    '"RG503" ]]; then',
    '"RG503" ]] || [[ "${1}" == "RG56PRO" ]]; then'
)

with open("build_RG351.sh", "w") as f:
    f.write(buildsh)

print("Patched src/def.h and build_RG351.sh for DEVICE_RG56PRO (1280x720)")
