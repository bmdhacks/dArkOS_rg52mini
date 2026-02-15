#!/usr/bin/env python3
"""Measure joystick ADC noise at rest to determine proper dead zone and fuzz values.

Usage:
    # Auto-detect rg56pro-joystick device, sample for 5 seconds:
    python3 measure_noise.py

    # Specify device and duration:
    python3 measure_noise.py /dev/input/event4 10

    # Pipe from evtest:
    evtest /dev/input/event4 | python3 measure_noise.py --evtest

DO NOT TOUCH THE CONTROLS while this runs.
"""

import struct, sys, os, time, math, glob, re

# ABS axis codes we care about
ABS_NAMES = {
    0x00: "ABS_X  (LX)",
    0x01: "ABS_Y  (LY)",
    0x02: "ABS_Z  (L2)",
    0x03: "ABS_RX (RX)",
    0x04: "ABS_RY (RY)",
    0x05: "ABS_RZ (R2)",
}

EV_ABS = 0x03

def find_device():
    """Find the rg56pro-joystick event device."""
    for path in sorted(glob.glob("/sys/class/input/event*/device/name")):
        try:
            with open(path) as f:
                if "rg56pro" in f.read():
                    num = re.search(r"event(\d+)", path).group(1)
                    return f"/dev/input/event{num}"
        except (IOError, AttributeError):
            continue
    return None

def read_device(dev_path, duration):
    """Read raw input_event structs from the evdev device."""
    # struct input_event on 64-bit: {long sec, long usec, u16 type, u16 code, s32 value}
    EVENT_SIZE = struct.calcsize("llHHi")
    EVENT_FMT = "llHHi"

    samples = {}  # code -> list of values

    print(f"Reading {dev_path} for {duration}s — DO NOT TOUCH ANYTHING")
    print()

    fd = os.open(dev_path, os.O_RDONLY | os.O_NONBLOCK)
    start = time.monotonic()

    try:
        while time.monotonic() - start < duration:
            try:
                data = os.read(fd, EVENT_SIZE * 32)
            except BlockingIOError:
                time.sleep(0.001)
                continue

            for off in range(0, len(data) - EVENT_SIZE + 1, EVENT_SIZE):
                _sec, _usec, ev_type, code, value = struct.unpack_from(
                    EVENT_FMT, data, off
                )
                if ev_type == EV_ABS and code in ABS_NAMES:
                    samples.setdefault(code, []).append(value)

            # Progress
            elapsed = time.monotonic() - start
            sys.stdout.write(f"\r  {elapsed:.1f}s / {duration}s")
            sys.stdout.flush()
    finally:
        os.close(fd)

    print("\r" + " " * 40 + "\r", end="")
    return samples

def parse_evtest(duration):
    """Parse piped evtest output from stdin."""
    samples = {}
    # Reverse lookup: name -> code
    name_to_code = {}
    for code, name in ABS_NAMES.items():
        short = name.split()[0]  # "ABS_X", "ABS_RX", etc.
        name_to_code[short] = code

    print(f"Reading evtest from stdin for {duration}s — DO NOT TOUCH ANYTHING")
    print()

    pat = re.compile(
        r"type 3 \(EV_ABS\), code \d+ \((\w+)\), value (-?\d+)"
    )

    start = time.monotonic()
    try:
        for line in sys.stdin:
            if time.monotonic() - start >= duration:
                break
            m = pat.search(line)
            if m:
                name, val = m.group(1), int(m.group(2))
                if name in name_to_code:
                    samples.setdefault(name_to_code[name], []).append(val)
    except KeyboardInterrupt:
        pass

    return samples

def analyze(samples):
    """Print noise statistics and recommended values."""
    print("=" * 72)
    print(f"{'Axis':<14} {'Count':>6} {'Min':>8} {'Max':>8} {'Range':>8} "
          f"{'Mean':>8} {'StdDev':>8} {'|Max|':>8}")
    print("-" * 72)

    axis_range_max = 32767
    recs = {}

    for code in sorted(ABS_NAMES):
        if code not in samples:
            print(f"{ABS_NAMES[code]:<14}   (no events)")
            continue

        vals = samples[code]
        lo, hi = min(vals), max(vals)
        mean = sum(vals) / len(vals)
        variance = sum((v - mean) ** 2 for v in vals) / len(vals)
        std = math.sqrt(variance)
        peak = max(abs(lo), abs(hi))
        span = hi - lo

        print(f"{ABS_NAMES[code]:<14} {len(vals):>6} {lo:>8} {hi:>8} {span:>8} "
              f"{mean:>8.1f} {std:>8.1f} {peak:>8}")

        recs[code] = {"peak": peak, "std": std, "span": span}

    print("=" * 72)
    print()

    # Recommendations
    stick_codes = [c for c in (0x00, 0x01, 0x03, 0x04) if c in recs]
    trig_codes = [c for c in (0x02, 0x05) if c in recs]

    if stick_codes:
        worst_peak = max(recs[c]["peak"] for c in stick_codes)
        worst_std = max(recs[c]["std"] for c in stick_codes)

        # Fuzz: ~3x stddev covers 99.7% of noise
        rec_fuzz = int(worst_std * 3.5 + 0.5)
        # Round up to power of 2
        rec_fuzz = 1 << (rec_fuzz - 1).bit_length() if rec_fuzz > 0 else 16
        rec_fuzz = max(rec_fuzz, 16)

        # Flat: above worst peak noise
        rec_flat = int(worst_peak * 1.3 + 0.5)
        rec_flat = 1 << (rec_flat - 1).bit_length() if rec_flat > 0 else 128
        rec_flat = max(rec_flat, 128)

        # Dead zone in mV: worst_peak maps back to a voltage offset
        # peak/32767 * (dz_to_edge_mV) = noise_mV  →  noise_mV ≈ peak/32767 * 640
        # But easier: just ensure dead zone margin > peak * range / 32767
        # With range ~640mV (882-250) on one side:
        noise_mv = int(worst_peak * 640 / axis_range_max + 0.5)
        rec_margin_mv = int(noise_mv * 1.4 / 10 + 0.5) * 10  # round up to 10mV
        rec_margin_mv = max(rec_margin_mv, 110)

        print("STICKS:")
        print(f"  Worst-case peak noise: {worst_peak} (of ±{axis_range_max})")
        print(f"  Worst-case stddev:     {worst_std:.0f}")
        print(f"  → Estimated noise:     ~{noise_mv} mV from center")
        print()
        print(f"  Recommended STICK_DZ_MARGIN_UV: {rec_margin_mv * 1000}")
        print(f"  Recommended stick fuzz:         {rec_fuzz}")
        print(f"  Recommended stick flat:         {rec_flat}")
        print()

    if trig_codes:
        worst_peak = max(recs[c]["peak"] for c in trig_codes)
        worst_std = max(recs[c]["std"] for c in trig_codes)

        rec_fuzz = int(worst_std * 3.5 + 0.5)
        rec_fuzz = 1 << (rec_fuzz - 1).bit_length() if rec_fuzz > 0 else 64
        rec_fuzz = max(rec_fuzz, 64)

        rec_flat = int(worst_peak * 1.3 + 0.5)
        rec_flat = 1 << (rec_flat - 1).bit_length() if rec_flat > 0 else 512
        rec_flat = max(rec_flat, 512)

        print("TRIGGERS:")
        print(f"  Worst-case peak noise: {worst_peak} (of 0–{axis_range_max})")
        print(f"  Worst-case stddev:     {worst_std:.0f}")
        print()
        print(f"  Recommended TRIG_FUZZ_CALIBRATED: {rec_fuzz}")
        print(f"  Recommended TRIG_FLAT_CALIBRATED:  {rec_flat}")
        print()

def main():
    args = sys.argv[1:]

    if "--evtest" in args:
        args.remove("--evtest")
        duration = int(args[0]) if args else 5
        samples = parse_evtest(duration)
    else:
        dev = None
        duration = 5
        for a in args:
            if a.startswith("/dev"):
                dev = a
            else:
                try:
                    duration = int(a)
                except ValueError:
                    pass

        if dev is None:
            dev = find_device()
            if dev is None:
                print("Could not find rg56pro-joystick device.")
                print("Usage: python3 measure_noise.py /dev/input/eventN [seconds]")
                sys.exit(1)

        samples = read_device(dev, duration)

    if not samples:
        print("No ABS events captured. Is the device correct?")
        sys.exit(1)

    analyze(samples)

if __name__ == "__main__":
    main()
