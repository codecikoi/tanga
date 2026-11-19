#!/usr/bin/env python3
"""Собирает рекламные скриншоты для App Store из снимков симулятора.

    python3 Tools/make_screenshots.py ru

Берёт AppStore/screenshots/<locale>/raw/*.png (снимки iPhone 6,9″, 1320×2868)
и собирает кадры: оранжевый фон, заголовок, телефон. Кладёт их в папки по размерам:
  1206x2622 — iPhone with Dynamic Island (medium display), обязательный размер;
  1320x2868 — iPhone with Dynamic Island (large display), по желанию.
Снимки делаются отладочной сборкой с аргументами -debugActive / -debugKeys / -debugRoute
(см. ConverterView.applyDebugLaunchArguments).
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

CAPTIONS = {
    "ru": {
        "01-main": "Все валюты мира\nв одном списке",
        "02-calc": "Считайте прямо\nпри вводе",
        "03-chart": "График любой\nпары валют",
        "04-crypto": "560+ криптовалют\nи золото",
        "05-picker": "Найдите любую\nиз 730 валют",
    },
    "en": {
        "01-main": "Every currency\nin one list",
        "02-calc": "Calculate\nas you type",
        "03-chart": "Charts for\nany pair",
        "04-crypto": "560+ cryptos\nand gold",
        "05-picker": "Find any of\n730 currencies",
    },
}

W, H = 1320, 2868                      # холст и снимки симулятора, iPhone 6,9″
OUTPUT_SIZES = [(1206, 2622), (1320, 2868)]   # medium (обязательный) и large display
TOP, BOTTOM = (255, 108, 50), (238, 72, 16)   # градиент вокруг фирменного #FF5A1F
FONT = "/System/Library/Fonts/SFNS.ttf"
FONT_SIZE = 112
CAPTION_TOP = 170
PHONE_TOP = 560
BOTTOM_MARGIN = 120
BEZEL = 26
ISLAND = (518, 42, 801, 151)           # Dynamic Island на снимке 1320×2868
SS = 4                                 # суперсэмплинг для гладких скруглений


def gradient() -> Image.Image:
    bg = Image.new("RGB", (W, H))
    draw = ImageDraw.Draw(bg)
    for y in range(H):
        t = y / (H - 1)
        draw.line([(0, y), (W, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return bg


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    big = Image.new("L", (size[0] * SS, size[1] * SS), 0)
    ImageDraw.Draw(big).rounded_rectangle([0, 0, big.width - 1, big.height - 1], radius * SS, fill=255)
    return big.resize(size, Image.LANCZOS)


def phone(shot: Image.Image) -> tuple[Image.Image, Image.Image]:
    """Телефон с экраном и его маска (для тени)."""
    shot = shot.convert("RGB").copy()
    # Таблетка попадает в снимки симулятора не всегда — рисуем её сами, чтобы на всех кадрах было одинаково.
    ImageDraw.Draw(shot).rounded_rectangle(ISLAND, (ISLAND[3] - ISLAND[1]) // 2, fill=(0, 0, 0))

    outer_h = H - PHONE_TOP - BOTTOM_MARGIN
    screen_h = outer_h - 2 * BEZEL
    screen_w = round(screen_h * shot.width / shot.height)
    screen = shot.resize((screen_w, screen_h), Image.LANCZOS)
    screen_r = round(screen_w * 0.125)

    size = (screen_w + 2 * BEZEL, outer_h)
    outer_r = screen_r + BEZEL
    # корпус: светлая кромка 3 px, внутри почти чёрная рамка, в ней экран
    body = Image.new("RGB", size, (70, 70, 74))
    inner = Image.new("L", size, 0)
    inner.paste(rounded_mask((size[0] - 6, size[1] - 6), outer_r - 3), (3, 3))
    body.paste((14, 14, 16), mask=inner)
    body.paste(screen, (BEZEL, BEZEL), rounded_mask(screen.size, screen_r))
    return body, rounded_mask(size, outer_r)


def caption(canvas: Image.Image, text: str) -> None:
    font = ImageFont.truetype(FONT, FONT_SIZE)
    font.set_variation_by_name("Bold")
    draw = ImageDraw.Draw(canvas)
    draw.multiline_text((W // 2, CAPTION_TOP), text, font=font, fill="white",
                        anchor="ma", align="center", spacing=round(FONT_SIZE * 0.18))


def compose(shot: Image.Image, text: str) -> Image.Image:
    canvas = gradient()
    caption(canvas, text)
    body, mask = phone(shot)
    x = (W - body.width) // 2

    shadow = Image.new("L", (W, H), 0)
    shadow.paste(mask, (x, PHONE_TOP + 30))
    shadow = shadow.filter(ImageFilter.GaussianBlur(45)).point(lambda v: v * 0.45)
    canvas.paste((90, 20, 0), mask=shadow)

    canvas.paste(body, (x, PHONE_TOP), mask)
    return canvas


def main() -> None:
    locale = sys.argv[1] if len(sys.argv) > 1 else "ru"
    root = Path(__file__).resolve().parent.parent / "AppStore" / "screenshots" / locale
    captions = CAPTIONS[locale]
    for raw in sorted((root / "raw").glob("*.png")):
        if raw.stem not in captions:
            print(f"skip {raw.name}: нет подписи")
            continue
        shot = Image.open(raw)
        if shot.size != (W, H):
            sys.exit(f"{raw.name}: {shot.size}, нужен снимок {W}×{H}")
        frame = compose(shot, captions[raw.stem])
        for size in OUTPUT_SIZES:
            folder = root / f"{size[0]}x{size[1]}"
            folder.mkdir(exist_ok=True)
            out = folder / raw.name
            (frame if size == frame.size else frame.resize(size, Image.LANCZOS)).save(out, optimize=True)
            print(f"{out.relative_to(root.parent.parent.parent)}")


if __name__ == "__main__":
    main()
