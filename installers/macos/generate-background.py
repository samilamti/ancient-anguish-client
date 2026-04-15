#!/usr/bin/env python3
"""Generate the DMG background image for Ancient Anguish Client.

Run once locally to produce dmg-background.png, then commit the PNG.
Requires: pip install Pillow

Usage: python3 installers/macos/generate-background.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

WIDTH, HEIGHT = 660, 400

# Icon center positions (must match build-dmg.sh --icon / --app-drop-link)
APP_X, APP_Y = 180, 170
DROP_X, DROP_Y = 480, 170
ICON_SIZE = 80

# Colors
BG_TOP = (28, 28, 36)
BG_BOTTOM = (18, 18, 24)
TEXT_PRIMARY = (220, 220, 230)
TEXT_SECONDARY = (160, 160, 175)
ARROW_COLOR = (100, 100, 120)
HIGHLIGHT = (90, 180, 255)


def lerp_color(c1: tuple, c2: tuple, t: float) -> tuple:
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def draw_gradient(img: Image.Image) -> None:
    draw = ImageDraw.Draw(img)
    for y in range(HEIGHT):
        color = lerp_color(BG_TOP, BG_BOTTOM, y / HEIGHT)
        draw.line([(0, y), (WIDTH, y)], fill=color)


def get_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    paths = [
        "/System/Library/Fonts/SFPro-Bold.otf" if bold else "/System/Library/Fonts/SFPro-Regular.otf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for p in paths:
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def draw_arrow(draw: ImageDraw.ImageDraw) -> None:
    """Draw a rightward arrow between the two icon zones."""
    y = APP_Y
    x_start = APP_X + ICON_SIZE // 2 + 16
    x_end = DROP_X - ICON_SIZE // 2 - 16
    shaft_y_half = 3

    # Shaft
    draw.rectangle(
        [x_start, y - shaft_y_half, x_end - 12, y + shaft_y_half],
        fill=ARROW_COLOR,
    )
    # Arrowhead
    head_size = 14
    draw.polygon(
        [
            (x_end, y),
            (x_end - head_size, y - head_size),
            (x_end - head_size, y + head_size),
        ],
        fill=ARROW_COLOR,
    )


def main() -> None:
    img = Image.new("RGB", (WIDTH, HEIGHT))
    draw_gradient(img)
    draw = ImageDraw.Draw(img)

    # Title
    title_font = get_font(26, bold=True)
    title = "Ancient Anguish Client"
    bbox = draw.textbbox((0, 0), title, font=title_font)
    tw = bbox[2] - bbox[0]
    draw.text(((WIDTH - tw) / 2, 40), title, fill=TEXT_PRIMARY, font=title_font)

    # Icon zone labels
    label_font = get_font(13)
    for label, cx in [("App", APP_X), ("Applications", DROP_X)]:
        bbox = draw.textbbox((0, 0), label, font=label_font)
        lw = bbox[2] - bbox[0]
        draw.text((cx - lw / 2, APP_Y + ICON_SIZE // 2 + 12), label, fill=TEXT_SECONDARY, font=label_font)

    # Arrow
    draw_arrow(draw)

    # "Drag to install" above arrow
    drag_font = get_font(14)
    drag_text = "Drag to install"
    bbox = draw.textbbox((0, 0), drag_text, font=drag_font)
    dw = bbox[2] - bbox[0]
    mid_x = (APP_X + DROP_X) / 2
    draw.text((mid_x - dw / 2, APP_Y - ICON_SIZE // 2 - 28), drag_text, fill=TEXT_SECONDARY, font=drag_font)

    # Gatekeeper instruction
    gate_font = get_font(15, bold=True)
    gate_text = "First launch: right-click the app \u2192 Open \u2192 Open"
    bbox = draw.textbbox((0, 0), gate_text, font=gate_font)
    gw = bbox[2] - bbox[0]
    draw.text(((WIDTH - gw) / 2, HEIGHT - 70), gate_text, fill=HIGHLIGHT, font=gate_font)

    # Subtle sub-text
    sub_font = get_font(11)
    sub_text = "macOS may block apps from unidentified developers"
    bbox = draw.textbbox((0, 0), sub_text, font=sub_font)
    sw = bbox[2] - bbox[0]
    draw.text(((WIDTH - sw) / 2, HEIGHT - 45), sub_text, fill=TEXT_SECONDARY, font=sub_font)

    out = Path(__file__).parent / "dmg-background.png"
    img.save(out, "PNG")
    print(f"Saved: {out}")


if __name__ == "__main__":
    main()
