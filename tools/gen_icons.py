"""Draws the OneGame icon (red twin-bell alarm clock) and the launch image,
then writes every Android / iOS size. Usage: python3 tools/gen_icons.py"""
import math
import pathlib

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent / "app"
RED = (232, 50, 47)
YELLOW = (255, 210, 63)
NIGHT = (18, 13, 14)
BONE = (244, 236, 228)
S = 1024


def clock(size, with_bg):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    k = size / S
    if with_bg:
        # Yellow → orange background, alarm energy.
        for y in range(size):
            t = y / size
            c = tuple(int(YELLOW[i] * (1 - t) + (255, 138, 61)[i] * t) for i in range(3))
            d.line([(0, y), (size, y)], fill=c + (255,))
    cx, cy, r = 512 * k, 560 * k, 300 * k

    def circle(x, y, rad, fill, outline=None, w=0):
        d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=fill, outline=outline, width=int(w))

    # Shadow.
    sh = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([cx - r, cy - r + 30 * k, cx + r, cy + r + 30 * k], fill=(0, 0, 0, 90))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(20 * k)))
    d = ImageDraw.Draw(img)
    # Legs.
    for s in (-1, 1):
        a = math.pi / 2 + s * 0.7
        d.line([(cx + math.cos(a) * r * 0.9, cy + math.sin(a) * r * 0.9),
                (cx + math.cos(a) * r * 1.22, cy + math.sin(a) * r * 1.22)], fill=NIGHT, width=int(44 * k))
    # Bells + hammer.
    for s in (-1, 1):
        a = -math.pi / 2 + s * 0.75
        bx, by = cx + math.cos(a) * r * 1.02, cy + math.sin(a) * r * 1.02
        circle(bx, by, 120 * k, RED, NIGHT, 20 * k)
    circle(cx, cy - r * 1.18, 34 * k, NIGHT)
    # Body + face.
    circle(cx, cy, r, RED)
    circle(cx, cy, r * 0.8, BONE)
    for i in range(12):
        a = i * math.pi / 6
        r1, r2 = r * 0.66, r * (0.5 if i % 3 == 0 else 0.6)
        d.line([(cx + math.cos(a) * r1, cy + math.sin(a) * r1), (cx + math.cos(a) * r2, cy + math.sin(a) * r2)],
               fill=NIGHT, width=int(16 * k))
    d.line([(cx, cy), (cx, cy - r * 0.5)], fill=NIGHT, width=int(26 * k))
    d.line([(cx, cy), (cx + r * 0.38, cy + r * 0.11)], fill=NIGHT, width=int(26 * k))
    circle(cx, cy, 26 * k, YELLOW)
    return img


def main():
    icon = clock(S, with_bg=True)
    rgb = icon.convert("RGB")
    ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for f in ios.glob("Icon-App-*.png"):
        base, scale = f.stem.replace("Icon-App-", "").split("@")
        px = round(float(base.split("x")[0]) * int(scale[0]))
        rgb.resize((px, px), Image.LANCZOS).save(f)
    for name, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        out = ROOT / f"android/app/src/main/res/mipmap-{name}/ic_launcher.png"
        icon.resize((px, px), Image.LANCZOS).save(out)
    # Launch image: the clock alone (transparent), shown on the night color.
    launch = clock(S, with_bg=False)
    li = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    for f, px in (("LaunchImage.png", 160), ("LaunchImage@2x.png", 320), ("LaunchImage@3x.png", 480)):
        launch.resize((px, px), Image.LANCZOS).save(li / f)
    for name, px in {"mdpi": 160, "hdpi": 240, "xhdpi": 320, "xxhdpi": 480, "xxxhdpi": 640}.items():
        d = ROOT / f"android/app/src/main/res/drawable-{name}"
        d.mkdir(exist_ok=True)
        launch.resize((px, px), Image.LANCZOS).save(d / "launch_image.png")
    icon.save(ROOT.parent / "docs/store/icon-1024.png") if (ROOT.parent / "docs/store").exists() else None
    print("icons written")


if __name__ == "__main__":
    main()
