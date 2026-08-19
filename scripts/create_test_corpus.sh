#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-./test_corpus}"
COUNT="${2:-10}"

echo "Creating synthetic test corpus at ${TARGET_DIR} with ${COUNT} images..."
mkdir -p "${TARGET_DIR}"

python3 - << PYEOF
import os, sys
from pathlib import Path
import struct

target = "${TARGET_DIR}"
count = int("${COUNT}")

# Create simple synthetic BMP images for testing
def create_bmp(filepath, r, g, b):
    w, h = 64, 64
    header = b'BM' + struct.pack('<IHHI', 54 + w*h*3, 0, 0, 54)
    info = struct.pack('<IIIHHIIIIII', 40, w, h, 1, 24, 0, w*h*3, 0, 0, 0, 0)
    pixels = bytes([b, g, r] * (w * h))
    with open(filepath, 'wb') as f:
        f.write(header + info + pixels)

for i in range(count):
    path = os.path.join(target, f"synthetic_photo_{i+1}.bmp")
    create_bmp(path, (i * 25) % 255, (i * 50) % 255, (i * 75) % 255)

print(f"Successfully generated {count} test images in {target}")
PYEOF
