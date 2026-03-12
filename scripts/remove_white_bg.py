#!/usr/bin/env python3
"""Fjerner hvid baggrund fra PNG-billeder. Pixels med R,G,B > threshold bliver transparente."""
import os
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Kør: pip install Pillow")
    exit(1)

ASSETS = Path(__file__).resolve().parent.parent / "assets"
# Kun pixels der er næsten rent hvide (alle kanaler > 252) bliver transparente.
# Lavere værdi = mere aggressiv (kan æde ind i lys pels/highlights). Hold høj for at bevare figuren.
WHITE_THRESHOLD = 252


def remove_white_bg(filepath: Path) -> bool:
    img = Image.open(filepath).convert("RGBA")
    data = img.getdata()
    new_data = []
    for item in data:
        r, g, b, a = item
        if r > WHITE_THRESHOLD and g > WHITE_THRESHOLD and b > WHITE_THRESHOLD:
            new_data.append((r, g, b, 0))
        else:
            # Bevar/restaurer fuld synlighed for figuren (fx lys pels)
            new_data.append((r, g, b, 255))
    img.putdata(new_data)
    img.save(filepath, "PNG", optimize=True)
    return True


def main():
    count = 0
    for f in sorted(ASSETS.glob("*angreb*.png")):
        try:
            remove_white_bg(f)
            count += 1
            print(f"  {f.name}")
        except Exception as e:
            print(f"  FEJL {f.name}: {e}")
    print(f"\nFærdig: {count} billeder opdateret.")


if __name__ == "__main__":
    main()
