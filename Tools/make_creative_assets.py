#!/usr/bin/env python3
"""Креативы для страницы в App Store (iOS 27+): шапка и карточка в поиске.

    python3 Tools/make_creative_assets.py

Пишет в AppStore/creative/:
  header.png      3840×1646 (21:9) — шапка страницы, без текста, общая для всех языков;
  search-ru.png   3840×2560 (3:2)  — карточка в результатах поиска, русская;
  search-en.png   3840×2560 (3:2)  — то же на английском.

Всё важное лежит внутри «art safe area» из спецификации Apple
(developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications),
остальное — фон, который на разных устройствах обрезается.
Телефон в карточке берёт снимок из AppStore/screenshots/<locale>/raw/01-main.png.
"""
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "AppStore" / "creative"
ICON = ROOT / "Tanga" / "Assets.xcassets" / "AppIcon.appiconset" / "icon-light.png"
FONT = "/System/Library/Fonts/SFNS.ttf"

BG = (17, 17, 19)
ORANGE = (255, 90, 31)
ISLAND = (518, 42, 801, 151)           # Dynamic Island на снимке 1320×2868

# (x, y, ширина, высота) безопасной зоны — из спецификации Apple
HEADER = {"size": (3840, 1646), "safe": (1097, 493, 1646, 661)}
SEARCH = {"size": (3840, 2560), "safe": (836, 765, 2168, 1030)}

TEXT = {
    "ru": ("Все валюты мира,\nкрипта и золото", "Живые курсы · калькулятор · графики"),
    "en": ("Every currency,\ncrypto and gold", "Live rates · calculator · charts"),
}

GLYPH_COLORS = {"₿": (255, 138, 61), "Au": (233, 196, 106), "Ag": (201, 206, 214)}

# Монеты: x, y, диаметр, символ, глубина (0 — резкая, 1–2 — дальше, размытее и прозрачнее)
HEADER_COINS = [
    # дальний план
    (300, 300, 170, "Ξ", 2), (520, 1320, 150, "₹", 2), (3500, 280, 160, "Ag", 2),
    (3600, 1250, 180, "$", 2), (1100, 140, 120, "€", 2), (2800, 1500, 130, "₿", 2),
    (150, 820, 140, "¥", 2), (3720, 760, 130, "₽", 2), (2350, 110, 110, "£", 2), (1500, 1540, 110, "₸", 2),
    # средний план
    (870, 443, 200, "₽", 1), (3000, 463, 210, "¥", 1), (670, 1083, 230, "£", 1),
    (3150, 1123, 220, "₸", 1), (1100, 1383, 160, "₺", 1), (2720, 263, 150, "₩", 1),
    # ближний план — внутри безопасной зоны
    (1360, 673, 220, "$", 0), (2480, 653, 230, "₿", 0), (1450, 1013, 190, "€", 0), (2420, 1023, 190, "Au", 0),
]

SEARCH_COINS = [
    (1100, 120, 110, "£", 2), (2700, 120, 110, "¥", 2), (1800, 2480, 110, "Au", 2),
    (3780, 900, 120, "€", 2), (60, 1600, 120, "₸", 2),
    (180, 700, 160, "₩", 1), (2000, 250, 150, "Ξ", 1), (3650, 330, 170, "₿", 1), (950, 2380, 150, "€", 1),
    (2900, 2370, 160, "₹", 1), (3700, 2250, 150, "$", 1), (120, 2300, 140, "₽", 1),
    (620, 560, 260, "₿", 0), (1500, 470, 200, "€", 0), (2350, 520, 210, "₽", 0), (3260, 640, 240, "Au", 0),
    (560, 1950, 220, "¥", 0), (1350, 2050, 200, "₸", 0), (2250, 2000, 230, "$", 0), (3300, 1900, 220, "£", 0),
    (3500, 1250, 190, "₺", 0), (380, 1250, 200, "Ag", 0),
]


def font(size: int, weight: str = "Bold") -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_name(weight)
    return f


def rounded_mask(size: tuple[int, int], radius: int, ss: int = 4) -> Image.Image:
    big = Image.new("L", (size[0] * ss, size[1] * ss), 0)
    ImageDraw.Draw(big).rounded_rectangle([0, 0, big.width - 1, big.height - 1], radius * ss, fill=255)
    return big.resize(size, Image.LANCZOS)


def background(size: tuple[int, int], glow: tuple[int, int], radii: tuple[int, int], strength: float = 0.4) -> Image.Image:
    """Тёмный фон с мягким эллиптическим оранжевым свечением.

    Градиент считается на полном разрешении и подмешивается шум ±1 уровень:
    на тёмных плавных переходах без него видны полосы.
    """
    w, h = size
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((x - glow[0]) / radii[0]) ** 2 + ((y - glow[1]) / radii[1]) ** 2)
    t = np.clip(1 - d, 0, 1) ** 2 * strength          # 0 по краям, strength в центре
    t = t[..., None]
    rgb = np.array(BG, np.float32) * (1 - t) + np.array(ORANGE, np.float32) * t
    rgb += np.random.default_rng(1).uniform(-1, 1, rgb.shape).astype(np.float32)
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def chart(canvas: Image.Image, start: tuple[int, int], end: tuple[int, int], width: int, seed: int) -> None:
    """Восходящая линия курса с заливкой — атмосфера на фоне."""
    rnd = random.Random(seed)
    n, wobble, pts = 48, 0.0, []
    for i in range(n + 1):
        t = i / n
        wobble = wobble * 0.8 + rnd.uniform(-1, 1) * canvas.height * 0.03
        pts.append((start[0] + (end[0] - start[0]) * t, start[1] + (end[1] - start[1]) * t + wobble))
    smooth = [pts[0]] + [
        tuple(sum(p[j] for p in pts[i - 1:i + 2]) / 3 for j in range(2)) for i in range(1, n)
    ] + [pts[-1]]
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.polygon(smooth + [(smooth[-1][0], canvas.height), (smooth[0][0], canvas.height)], fill=ORANGE + (20,))
    draw.line(smooth, fill=ORANGE + (170,), width=width, joint="curve")
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(1.5)))


def coin(diameter: int, glyph: str) -> Image.Image:
    ss = 3
    d = diameter * ss
    tile = Image.new("RGBA", (d, d), (0, 0, 0, 0))
    draw = ImageDraw.Draw(tile)
    ring = max(3, d // 45)
    draw.ellipse([0, 0, d - 1, d - 1], fill=(72, 72, 80, 255))
    draw.ellipse([ring, ring, d - 1 - ring, d - 1 - ring], fill=(36, 36, 41, 255))
    size = int(d * (0.40 if len(glyph) > 1 else 0.50))
    draw.text((d / 2, d / 2), glyph, font=font(size), fill=GLYPH_COLORS.get(glyph, (240, 240, 245)) + (255,), anchor="mm")
    return tile.resize((diameter, diameter), Image.LANCZOS)


def place_coin(canvas: Image.Image, x: int, y: int, diameter: int, glyph: str, depth: int) -> None:
    pad = 40 + depth * 20
    tile = Image.new("RGBA", (diameter + 2 * pad, diameter + 2 * pad), (0, 0, 0, 0))
    if depth == 0:   # мягкая тень под ближними монетами
        shadow = Image.new("RGBA", tile.size, (0, 0, 0, 0))
        ImageDraw.Draw(shadow).ellipse([pad, pad + diameter * 0.08, pad + diameter, pad + diameter * 1.08], fill=(0, 0, 0, 150))
        tile.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(diameter * 0.08)))
    tile.alpha_composite(coin(diameter, glyph), (pad, pad))
    if depth:
        tile = tile.filter(ImageFilter.GaussianBlur(depth * 4))
        tile.putalpha(tile.getchannel("A").point(lambda v: int(v * (1 - 0.3 * depth))))
    canvas.alpha_composite(tile, (x - diameter // 2 - pad, y - diameter // 2 - pad))


def app_icon(size: int) -> Image.Image:
    icon = Image.open(ICON).convert("RGB").resize((size, size), Image.LANCZOS).convert("RGBA")
    icon.putalpha(rounded_mask((size, size), round(size * 0.2237)))
    return icon


def place_icon(canvas: Image.Image, cx: int, cy: int, size: int, glow: bool) -> None:
    pad = size // 2
    tile = Image.new("RGBA", (size + 2 * pad, size + 2 * pad), (0, 0, 0, 0))
    halo = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(halo)
    if glow:
        draw.ellipse([pad * 0.6, pad * 0.6, tile.width - pad * 0.6, tile.height - pad * 0.6], fill=ORANGE + (110,))
    draw.rounded_rectangle([pad, pad + size * 0.06, pad + size, pad + size * 1.06], size * 0.22, fill=(0, 0, 0, 170))
    tile.alpha_composite(halo.filter(ImageFilter.GaussianBlur(size * 0.12)))
    tile.alpha_composite(app_icon(size), (pad, pad))
    canvas.alpha_composite(tile, (cx - size // 2 - pad, cy - size // 2 - pad))


def phone(shot_path: Path, outer_h: int) -> Image.Image:
    shot = Image.open(shot_path).convert("RGB")
    ImageDraw.Draw(shot).rounded_rectangle(ISLAND, (ISLAND[3] - ISLAND[1]) // 2, fill=(0, 0, 0))
    bezel = round(outer_h * 0.0118)
    rim = max(2, round(outer_h * 0.0014))
    screen_h = outer_h - 2 * bezel
    screen_w = round(screen_h * shot.width / shot.height)
    screen_r = round(screen_w * 0.125)
    size = (screen_w + 2 * bezel, outer_h)
    body = Image.new("RGBA", size, (70, 70, 74, 255))
    inner = Image.new("L", size, 0)
    inner.paste(rounded_mask((size[0] - 2 * rim, size[1] - 2 * rim), screen_r + bezel - rim), (rim, rim))
    body.paste((14, 14, 16, 255), mask=inner)
    body.paste(shot.resize((screen_w, screen_h), Image.LANCZOS), (bezel, bezel), rounded_mask((screen_w, screen_h), screen_r))
    body.putalpha(rounded_mask(size, screen_r + bezel))
    return body


def place_phone(canvas: Image.Image, body: Image.Image, x: int, y: int) -> None:
    shadow = Image.new("RGBA", (body.width + 400, body.height + 400), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 200), (200, 230), body.getchannel("A"))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(60)), (x - 200, y - 200))
    canvas.alpha_composite(body, (x, y))


def header() -> Image.Image:
    w, h = HEADER["size"]
    canvas = background((w, h), (w // 2, h // 2), (1900, 1100), strength=0.45)
    chart(canvas, (0, 1380), (w, 380), width=10, seed=7)
    for c in HEADER_COINS:
        place_coin(canvas, *c)
    place_icon(canvas, w // 2, h // 2, 500, glow=True)
    return canvas


def search(locale: str) -> Image.Image:
    w, h = SEARCH["size"]
    sx, sy, sw, sh = SEARCH["safe"]
    canvas = background((w, h), (w // 2 + 300, h // 2), (2300, 1700), strength=0.42)
    chart(canvas, (0, 2400), (w, 1840), width=10, seed=11)
    for c in SEARCH_COINS:
        place_coin(canvas, *c)

    body = phone(ROOT / "AppStore" / "screenshots" / locale / "raw" / "01-main.png", sh)
    phone_x = sx + sw - body.width - 20
    place_phone(canvas, body, phone_x, sy)

    title, subtitle = TEXT[locale]
    left, right = sx + 30, phone_x - 110
    draw = ImageDraw.Draw(canvas)
    size = 160
    while True:   # заголовок должен поместиться слева от телефона
        title_font = font(size)
        tb = draw.multiline_textbbox((0, 0), title, font=title_font, spacing=round(size * 0.14))
        if tb[2] - tb[0] <= right - left or size <= 90:
            break
        size -= 4
    sub_font = font(round(size * 0.42), "Semibold")
    sb = draw.textbbox((0, 0), subtitle, font=sub_font)
    icon_size = 210
    gap_icon, gap_sub = 70, 56
    block = icon_size + gap_icon + (tb[3] - tb[1]) + gap_sub + (sb[3] - sb[1])
    top = sy + (sh - block) // 2

    place_icon(canvas, left + icon_size // 2, top + icon_size // 2, icon_size, glow=False)
    y = top + icon_size + gap_icon
    draw = ImageDraw.Draw(canvas)
    draw.multiline_text((left - tb[0], y - tb[1]), title, font=title_font, fill="white", spacing=round(size * 0.14))
    y += tb[3] - tb[1] + gap_sub
    draw.text((left - sb[0], y - sb[1]), subtitle, font=sub_font, fill=(176, 176, 184))
    return canvas


def save(image: Image.Image, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    image.convert("RGB").save(path, optimize=True)
    print(f"{path.relative_to(ROOT)}  {image.width}×{image.height}")


def main() -> None:
    save(header(), "header.png")
    for locale in TEXT:
        save(search(locale), f"search-{locale}.png")


if __name__ == "__main__":
    main()
