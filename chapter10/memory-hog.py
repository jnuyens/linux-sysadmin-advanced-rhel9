#!/usr/bin/env python3
"""Memory Hog - Chapter 10 Exercise

Allocates memory in 1 MB chunks until killed by the OOM killer
or the user presses Ctrl+C.

Usage:
    python3 memory-hog.py [MB]
    python3 memory-hog.py 500    # allocate 500 MB then wait
    python3 memory-hog.py 0      # allocate until OOM kills us

WARNING: Run inside a cgroup with MemoryMax set, or in a VM/container.
         Do NOT run on a production system.

Safe testing with systemd-run:
    sudo systemd-run --scope -p MemoryMax=256M python3 memory-hog.py 0
"""

import sys
import os
import signal

def handler(sig, frame):
    print("\nInterrupted. Releasing memory.")
    sys.exit(0)

signal.signal(signal.SIGINT, handler)

target_mb = int(sys.argv[1]) if len(sys.argv) > 1 else 500
unlimited = (target_mb == 0)

blocks = []
allocated = 0

if unlimited:
    print("Allocating memory until OOM killer intervenes...")
    print("Press Ctrl+C to stop early.\n")
else:
    print(f"Allocating {target_mb} MB of memory...")

try:
    while unlimited or allocated < target_mb:
        # Allocate 1 MB of actual data (not just virtual)
        blocks.append(b'x' * 1024 * 1024)
        allocated += 1

        if allocated % 50 == 0:
            print(f"  {allocated} MB allocated (PID {os.getpid()})")

except MemoryError:
    print(f"\nMemoryError after {allocated} MB. System refused allocation.")
    sys.exit(1)

print(f"\nDone: {allocated} MB allocated. PID {os.getpid()}")
print("Memory is held. Press Enter to release, or wait for OOM killer.")

try:
    input()
except EOFError:
    pass

print("Releasing memory.")
