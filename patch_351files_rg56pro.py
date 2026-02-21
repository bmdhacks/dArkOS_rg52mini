#!/usr/bin/env python3
"""Patch 351Files source to add DEVICE_RG56PRO and DEVICE_RG43H support.

RG56PRO: 1280x720 (portrait, rotated via SDL2 RGA)
RG43H:   1024x768 (landscape native)

Both use the rk3562-joystick driver which has different joydev button
indices from the retrogame_joypad (RG503).  The key differences:

  retrogame_joypad (RG503):  dpad 13-16, start b9, back b8, L2 b6, R2 b7
  rk3562-joystick:           dpad 12-15, start b8, back b7, L2/R2 analog only
"""

# --- Patch src/def.h ---

with open("src/def.h") as f:
    defh = f.read()

# Step 1: Blanket replace — add both devices wherever RG503 appears.
# This handles all #elif chains (buttons, screen params, etc.)
defh = defh.replace(
    "defined(DEVICE_RG503)",
    "defined(DEVICE_RG503) || defined(DEVICE_RG56PRO) || defined(DEVICE_RG43H)"
)

# Step 2: Fix BUTTON section — insert proper rk3562 button block and
# revert the combined guard back to RG503-only for that section.
#
# rk3562-joystick joydev button indices:
#   b0=B(south) b1=A(east) b2=X(north) b3=Y(west)
#   b4=L1 b5=R1 b6=BACK(TL2) b7=SELECT b8=START b9=HOME/FN(MODE)
#   b10=L3 b11=R3 b12=DPadUp b13=DPadDown b14=DPadLeft b15=DPadRight
#
# L2/R2 are analog axes (a2/a5), not buttons — no secondary page key.

rk3562_button_block = """\
#elif defined(DEVICE_RG56PRO) || defined(DEVICE_RG43H)
   #define BUTTON_PRESSED_UP              event.type == SDL_JOYBUTTONDOWN && event.jbutton.button == 12
   #define BUTTON_PRESSED_DOWN            event.type == SDL_JOYBUTTONDOWN && event.jbutton.button == 13
   #define BUTTON_PRESSED_LEFT            event.type == SDL_JOYBUTTONDOWN && event.jbutton.button == 14
   #define BUTTON_PRESSED_RIGHT           event.type == SDL_JOYBUTTONDOWN && event.jbutton.button == 15
   #define BUTTON_PRESSED_PAGEUP          event.type == SDL_JOYBUTTONDOWN && event.jbutton.button == 4
   #define BUTTON_PRESSED_PAGEDOWN        event.type == SDL_JOYBUTTONDOWN && event.jbutton.button == 5
   #define BUTTON_PRESSED_VALIDATE        event.type == SDL_JOYBUTTONDOWN && event.jbutton.button == 1
   #define BUTTON_PRESSED_BACK            event.type == SDL_JOYBUTTONDOWN && event.jbutton.button == 0
   #define BUTTON_PRESSED_MENU_CONTEXT    event.type == SDL_JOYBUTTONDOWN && event.jbutton.button == 2
   #define BUTTON_PRESSED_SELECT          event.type == SDL_JOYBUTTONDOWN && event.jbutton.button == 3
   #define BUTTON_HELD_UP                 SDL_JoystickGetButton(g_joystick, 12)
   #define BUTTON_HELD_DOWN               SDL_JoystickGetButton(g_joystick, 13)
   #define BUTTON_HELD_LEFT               SDL_JoystickGetButton(g_joystick, 14)
   #define BUTTON_HELD_RIGHT              SDL_JoystickGetButton(g_joystick, 15)
   #define BUTTON_HELD_PAGEUP             SDL_JoystickGetButton(g_joystick, 4)
   #define BUTTON_HELD_PAGEDOWN           SDL_JoystickGetButton(g_joystick, 5)
   #define BUTTON_HELD_SELECT             SDL_JoystickGetButton(g_joystick, 3)
   #define BUTTON_HELD_VALIDATE           SDL_JoystickGetButton(g_joystick, 1)
"""

defh = defh.replace(
    "#elif defined(DEVICE_RG503) || defined(DEVICE_RG56PRO) || defined(DEVICE_RG43H)\n"
    "   #define BUTTON_PRESSED_UP",
    rk3562_button_block
    + "#elif defined(DEVICE_RG503)\n"
    "   #define BUTTON_PRESSED_UP"
)

# Step 3: Fix SCREEN section — insert per-device screen blocks and
# revert the combined guard back to RG503-only for that section.

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

rg43h_screen_block = """\
#elif defined(DEVICE_RG43H)
   #define SCREEN_WIDTH             1024
   #define SCREEN_HEIGHT            768
   #define HARDWARE_ACCELERATION    0
   #define FULLSCREEN               1
   #define FONT_NAME                "NotoSans-Regular.ttf"
   #define FONT_NAME_MONO           "NotoSansMono-Regular.ttf"
   #define FONT_SIZE                22
   #define LINE_HEIGHT              34
   #define ICON_SIZE                28
   #define MARGIN_X                 12
   #define KEYBOARD_MARGIN          8
   #define KEYBOARD_KEY_SPACING     4
   #define KEYBOARD_SYMBOL_SIZE     26
"""

defh = defh.replace(
    "#elif defined(DEVICE_RG503) || defined(DEVICE_RG56PRO) || defined(DEVICE_RG43H)\n"
    "   #define SCREEN_WIDTH",
    rg56pro_screen_block
    + rg43h_screen_block
    + "#elif defined(DEVICE_RG503)\n"
    "   #define SCREEN_WIDTH"
)

with open("src/def.h", "w") as f:
    f.write(defh)

# --- Patch build_RG351.sh ---
# Add RG56PRO and RG43H to the conditional that triggers dual-build
# (/roms and /roms2)

with open("build_RG351.sh") as f:
    buildsh = f.read()

buildsh = buildsh.replace(
    '"RG503" ]]; then',
    '"RG503" ]] || [[ "${1}" == "RG56PRO" ]] || [[ "${1}" == "RG43H" ]]; then'
)

with open("build_RG351.sh", "w") as f:
    f.write(buildsh)

print("Patched src/def.h and build_RG351.sh for DEVICE_RG56PRO (1280x720) and DEVICE_RG43H (1024x768)")
