#!/usr/bin/env python3
"""Generate the Ventline app icon.

Committed as a script rather than as a binary someone once exported, for the
same reason scripts/build-fonts.py is: the artefact in the repo can be
regenerated and argued with, instead of being a file nobody dares touch.

The mark is a V with air running into it. Ventline is Lüftung, and a bare
letterform says nothing about what the app is for; three strokes of airflow do,
without turning into an illustration that dissolves at 40 px.

Design constraints, in the order they mattered:

  1. **Legible at 58 px.** That is the Settings-app size, and a jobsite phone
     with a cracked screen in daylight is closer to that than to the 1024 you
     are looking at while designing. Every decision here was made on a contact
     sheet at 180/120/80/58, not at full size. An earlier version with the
     airflow at three different lengths and a lighter stroke turned to mush.
  2. **Dark ground.** Most home-screen icons are light; slate-900 stands out
     between them, and it is already the colour of the web app's chrome.
  3. **Cool accent, not warm.** Sky blue reads as air. Orange or red would read
     as heating — the neighbouring trade, and the wrong one.
  4. **No transparency, no pre-rounded corners.** iOS masks the corners itself
     and rejects an alpha channel on the App Store icon.

Run: python3 scripts/build-app-icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
SS = 4  # supersample factor; diagonals are the whole mark, so 4x it is

SLATE_900 = (15, 23, 42)
SLATE_800 = (30, 41, 59)
WHITE = (255, 255, 255)
SKY_400 = (56, 189, 248)

OUT = (
    Path(__file__).resolve().parent.parent
    / "ios/Ventline/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
)


def background() -> Image.Image:
    """A slight vertical lift, so the ground is not a flat rectangle."""
    img = Image.new("RGB", (SIZE * SS, SIZE * SS), SLATE_900)
    draw = ImageDraw.Draw(img)
    height = SIZE * SS
    for y in range(height):
        t = y / height
        draw.line(
            [(0, y), (SIZE * SS, y)],
            fill=tuple(
                round(SLATE_900[i] + (SLATE_800[i] - SLATE_900[i]) * t)
                for i in range(3)
            ),
        )
    return img


def round_capped_line(draw, points, width, fill):
    """PIL strokes with butt caps; the discs put the round ends back on."""
    draw.line(points, fill=fill, width=width, joint="curve")
    radius = width // 2
    for x, y in (points[0], points[-1]):
        draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=fill)


def render() -> Image.Image:
    img = background()
    draw = ImageDraw.Draw(img)

    # Laid out from the group's own width rather than by eye: the airflow and
    # the V are centred *together*, or the V alone looks pushed to the right.
    line_length = 190
    gap = 78
    v_half_width = 225
    group_width = line_length + gap + v_half_width * 2
    left = (SIZE - group_width) / 2

    lines_end = left + line_length
    v_centre = lines_end + gap + v_half_width
    top, bottom = 322, 726

    round_capped_line(
        draw,
        [
            (round((v_centre - v_half_width) * SS), round(top * SS)),
            (round(v_centre * SS), round(bottom * SS)),
            (round((v_centre + v_half_width) * SS), round(top * SS)),
        ],
        width=round(118 * SS),
        fill=WHITE,
    )

    # Longest line in the middle, so the airflow's silhouette echoes the taper
    # of the V it is running into.
    middle = (top + bottom) / 2
    for index, offset in enumerate((-118, 0, 118)):
        length = line_length - abs(index - 1) * 46
        y = round((middle + offset) * SS)
        round_capped_line(
            draw,
            [(round((lines_end - length) * SS), y), (round(lines_end * SS), y)],
            width=round(52 * SS),
            fill=SKY_400,
        )

    return img.resize((SIZE, SIZE), Image.LANCZOS)


if __name__ == "__main__":
    icon = render()
    assert icon.mode == "RGB", "the App Store icon must not carry an alpha channel"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    icon.save(OUT, format="PNG")
    print(f"wrote {OUT.relative_to(Path.cwd())} ({icon.size[0]}x{icon.size[1]}, {icon.mode})")
