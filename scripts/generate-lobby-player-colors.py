#!/usr/bin/env python3
"""Derive lobby suit colors from the exact user-supplied standing crewmate crop."""

import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "IRLAmongUs" / "Assets.xcassets"
SOURCE = ASSETS / "LobbyPlayer.imageset" / "lobby-player.png"
WIDTH, HEIGHT = 147, 190
PALETTE = {
    "Red": (197, 17, 17),
    "Blue": (19, 46, 210),
    "Green": (17, 128, 45),
    "Pink": (238, 84, 187),
    "Orange": (240, 125, 13),
    "Yellow": (246, 246, 87),
    "Black": (63, 71, 78),
    "White": (215, 225, 241),
    "Purple": (107, 47, 188),
    "Brown": (113, 73, 30),
    "Cyan": (56, 255, 221),
    "Lime": (80, 240, 57),
    "Maroon": (80, 15, 27),
    "Rose": (236, 113, 151),
    "Banana": (255, 255, 190),
}


def recolor(target: tuple[int, int, int]) -> bytes:
    pixels = bytearray(subprocess.check_output(["magick", str(SOURCE), "-depth", "8", "rgba:-"]))
    for offset in range(0, len(pixels), 4):
        red, green, blue, alpha = pixels[offset : offset + 4]
        if not alpha:
            continue
        bright_suit = red > 55 and red > green * 1.4 and red > blue * 1.3
        shaded_suit = blue > 55 and blue > red * 1.4 and blue > green * 1.2
        if not (bright_suit or shaded_suit):
            continue
        intensity = max(red, green, blue) / 255
        shade = 1 if bright_suit else 0.52
        for channel in range(3):
            pixels[offset + channel] = round(target[channel] * intensity * shade)
    return bytes(pixels)


for color_name, rgb in PALETTE.items():
    asset_name = f"LobbyPlayer{color_name}"
    folder = ASSETS / f"{asset_name}.imageset"
    folder.mkdir(exist_ok=True)
    subprocess.run(
        ["magick", "-size", f"{WIDTH}x{HEIGHT}", "-depth", "8", "rgba:-", str(folder / f"{asset_name}.png")],
        input=recolor(rgb),
        check=True,
    )
    contents = {
        "images": [{"filename": f"{asset_name}.png", "idiom": "universal", "scale": "1x"}],
        "info": {"author": "xcode", "version": 1},
    }
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
