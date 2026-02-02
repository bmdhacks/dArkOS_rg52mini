#!/usr/bin/env python3

import evdev
import asyncio
import time
from subprocess import check_output
import os
import argparse
import sys

# Parse command-line arguments
parser = argparse.ArgumentParser(description="Kill a process when button combo is pressed")
parser.add_argument("process_name", help="Name of the process to kill (e.g., hypseus)")
args = parser.parse_args()

# Define per-controller key mappings
JOY_MAPPINGS = {
    "retrogame_joypad": {
        "f1": 314,
        "f3": 315
    },
    "GO-Super Gamepad": {
        "f1": 704,
        "f3": 705
    },
    "gameforce_gamepad": {
        "f1": 704,
        "f3": 315
    },
    "OpenSimHardware OSH PB Controller": {
        "f1": 311,
        "f3": 310
    },
    "GO-Advance Gamepad (rev 1.1)": {
        "f1": 705,
        "f3": 709
    },
    "GO-Advance Gamepad": {
        "f1": 704,
        "f3": 709
    },
    "rg56pro-joystick": {
        "f1": 314,
        "f3": 315
    }
}

# Scan for the first available input device matching a known controller
def detect_joypad():
    for path in evdev.list_devices():
        device = evdev.InputDevice(path)
        if device.name in JOY_MAPPINGS:
            print(f"Using detected device: {device.name} ({path})")
            return device, JOY_MAPPINGS[device.name]
    # Fallback: just pick the first device and default mapping
    fallback_device = evdev.InputDevice(evdev.list_devices()[0])
    print(f"No known controller matched. Falling back to: {fallback_device.name}")
    return fallback_device, JOY_MAPPINGS["GO-Advance Gamepad"]

# Detect device and keymap
arkos_joypad, keymap = detect_joypad()

# Run a shell command
def runcmd(cmd, *args, **kw):
    print(f">>> {cmd}")
    check_output(cmd, *args, **kw)

# Event handler
async def handle_event(device):
    async for event in device.async_read_loop():
        keys = device.active_keys()
        if keymap["f1"] in keys and event.code == keymap["f3"]:
            runcmd(f"pkill {args.process_name}*; if [ ! -z $(pidof {args.process_name}) ]; then sudo kill -9 $(pidof {args.process_name}); fi", shell=True)
            sys.exit(0)

# Main run loop
def run():
    asyncio.ensure_future(handle_event(arkos_joypad))
    loop = asyncio.get_event_loop()
    loop.run_forever()

if __name__ == "__main__":
    run()
