#!/usr/bin/env python3
"""Generate the Ventline app icon.

Committed as a script rather than as a binary someone once exported, for the
same reason scripts/build-fonts.py is: the artefact in the repo can be
regenerated and argued with, instead of being a file nobody dares touch.

The mark is three stacked V's — Ventline's initial, repeated so that the
repetition itself reads as airflow. Ventline is Lüftung, and a single static
letterform says nothing about what the app is for.

Design constraints, in the order they mattered:

  1. **Legible at 58 px.** That is the Settings-app size, and a jobsite phone
     with a cracked screen in daylight is closer to that than to the 1024 you
     are looking at while designing. Every decision here was made on a contact
     sheet at 180/120/80/58, not at full size.
  2. **Separated by hue, not by opacity.** The first version faded the lower
     two chevrons to grey. Downsampling turns low-contrast grey into mud and
     the third V simply vanished at 58 px; a colour descent survives, because
     hue is still hue at four pixels wide.
  3. **Tight enough to be one mark.** Spread out, three chevrons read as three
     separate arrows. The spacing is just under the stroke width, so the group
     holds together as a single silhouette.
  4. **Dark ground.** Most home-screen icons are light; slate-900 stands out
     between them, and it is already the colour of the web app's chrome.
  5. **No transparency, no pre-rounded corners.** iOS masks the corners itself
     and rejects an alpha channel on the App Store icon.

Run: python3 scripts/build-app-icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
SS = 4  # supersample factor; the mark is nothing but diagonals, so 4x it is

SLATE_900 = (15, 23, 42)
SLATE_800 = (30, 41, 59)
WHITE = (255, 255, 255)
SKY_400 = (56, 189, 248)
SKY_600 = (2, 132, 199)

# One chevron per row: the lead in white, then a descent through sky. The
# darkest still sits clearly off slate-900 — one step further down the ramp and
# it started sinking into the background at small sizes.
CHEVRONS = ((300, WHITE), (436, SKY_400), (572, SKY_600))

CENTRE_X = 512
HALF_WIDTH = 232
DROP = 182
STROKE = 88

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


def chevron(draw, top: int, fill) -> None:
    """One V. PIL strokes with butt caps; the discs put the round ends back."""
    points = [
        (round((CENTRE_X - HALF_WIDTH) * SS), round(top * SS)),
        (round(CENTRE_X * SS), round((top + DROP) * SS)),
        (round((CENTRE_X + HALF_WIDTH) * SS), round(top * SS)),
    ]
    width = round(STROKE * SS)
    draw.line(points, fill=fill, width=width, joint="curve")
    radius = width // 2
    for x, y in (points[0], points[-1]):
        draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=fill)


def render() -> Image.Image:
    img = background()
    draw = ImageDraw.Draw(img)
    for top, fill in CHEVRONS:
        chevron(draw, top, fill)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


if __name__ == "__main__":
    icon = render()
    assert icon.mode == "RGB", "the App Store icon must not carry an alpha channel"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    icon.save(OUT, format="PNG")
    print(f"wrote {OUT} ({icon.size[0]}x{icon.size[1]}, {icon.mode})")
