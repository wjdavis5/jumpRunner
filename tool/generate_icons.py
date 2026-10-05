"""Builds every app icon from the game's own courier sprite.

    python tool/generate_icons.py [--preview DIR]

Run from the repository root. Needs Pillow and numpy. The output depends only
on `assets/images/courier/jump.png` and the numbers in this file, so running
it twice writes the same pixels.

What it writes:

* web: `favicon.png`, `icons/Icon-{192,512}.png` (rounded tile) and
  `icons/Icon-maskable-{192,512}.png` (full bleed, art inside the safe zone)
* Android: `mipmap-*/ic_launcher.png` (rounded tile, for Android 7 and
  older) and the adaptive pair `ic_launcher_background.png` /
  `ic_launcher_foreground.png` used by `mipmap-anydpi-v26/ic_launcher.xml`
* iOS: every size named in `AppIcon.appiconset/Contents.json`, with no alpha
  channel (App Store Connect rejects icons that have one)

The courier sprite is 80x110. Scaling it up twelve times with an ordinary
filter gives mush, so it is redrawn instead: each of its flat colours is
scaled as its own soft mask and every big pixel takes the colour whose mask
is strongest there. That keeps the edges sharp and the curves round.
"""

import argparse
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITE = os.path.join(ROOT, 'assets', 'images', 'courier', 'jump.png')

MASTER = 2048  # every icon is drawn at this size and scaled down
REDRAW = 16  # how many times bigger the courier is redrawn

# The sky at dusk, top to bottom, then the game's gold for the sun's glow.
SKY = [(0.00, (22, 30, 74)), (0.45, (78, 52, 132)), (0.80, (214, 96, 96)), (1.00, (246, 150, 78))]
SUN = (255, 209, 102)
SKYLINE = (19, 23, 48)
WINDOW = (255, 209, 102)

# The part of the sprite the icon shows: head, raised fist and shoulders.
# Native sprite pixels.
BUST_LEFT, BUST_RIGHT = 4.0, 78.0
HEAD_CENTER_X, HEAD_CENTER_Y = 41.0, 33.0


def redraw_sprite(path, factor):
    """The sprite, `factor` times bigger, as a sharp RGBA image."""
    sprite = np.asarray(Image.open(path).convert('RGBA')).astype(np.float64)
    height, width = sprite.shape[:2]
    rgb, cover = sprite[:, :, :3], sprite[:, :, 3] / 255.0

    # The flat colours the sprite is drawn in: anything covering 25 pixels.
    # Every other colour is a one-pixel blend along an edge between two of
    # them, and says how far into that pixel the edge runs.
    colours, counts = np.unique(
        rgb[cover > 0.98].astype(np.int32), axis=0, return_counts=True)
    order = np.lexsort((colours[:, 2], colours[:, 1], colours[:, 0], -counts))
    palette = colours[order][np.sort(counts)[::-1] >= 25].astype(np.float64)

    # Split each pixel between its two nearest flat colours, by where it
    # lies on the line from one to the other.
    distance = ((rgb[:, :, None, :] - palette[None, None, :, :]) ** 2).sum(axis=3)
    nearest = np.argsort(distance, axis=2)[:, :, :2]
    first, second = palette[nearest[:, :, 0]], palette[nearest[:, :, 1]]
    span = second - first
    along = ((rgb - first) * span).sum(axis=2) / np.maximum((span ** 2).sum(axis=2), 1e-9)
    along = np.clip(along, 0.0, 0.5)  # past halfway it would be the other one

    share = np.zeros((height, width, len(palette)))
    rows, cols = np.indices((height, width))
    share[rows, cols, nearest[:, :, 0]] = 1.0 - along
    share[rows, cols, nearest[:, :, 1]] += along
    share *= cover[:, :, None]

    big = (width * factor, height * factor)
    blur = ImageFilter.GaussianBlur(factor * 0.30)

    def soften(mask):
        image = Image.fromarray(np.round(mask * 255).astype(np.uint8), 'L')
        return np.asarray(image.resize(big, Image.BICUBIC).filter(blur)).astype(np.float32)

    best = np.zeros((big[1], big[0]), np.float32) - 1.0
    winner = np.zeros((big[1], big[0]), np.int32)
    for index in range(len(palette)):
        strength = soften(share[:, :, index])
        ahead = strength > best
        winner[ahead] = index
        best[ahead] = strength[ahead]

    # Where two colours meet, a third that happens to lie between them can
    # win a sliver a few pixels wide. Taking the commonest colour in each
    # neighbourhood removes the slivers and leaves real features alone.
    tidy = Image.fromarray(winner.astype(np.uint8), 'L').filter(ImageFilter.ModeFilter(factor - 1))
    winner = np.asarray(tidy).astype(np.int32)

    out = np.zeros((big[1], big[0], 4), np.uint8)
    out[:, :, :3] = palette[winner].astype(np.uint8)
    out[:, :, 3] = np.where(soften(cover) >= 127.5, 255, 0)
    return Image.fromarray(out, 'RGBA')


def sky(size):
    """The dusk gradient, sun and skyline, with no courier."""
    rows = np.linspace(0.0, 1.0, size)
    stops = [s for s, _ in SKY]
    channels = [np.interp(rows, stops, [c[i] for _, c in SKY]) for i in range(3)]
    column = np.stack(channels, axis=1)
    image = Image.fromarray(np.repeat(column[:, None, :], size, axis=1).astype(np.uint8), 'RGB')

    # The last of the sun, as a glow low behind the courier.
    centre, radius = (0.50 * size, 0.58 * size), 0.40 * size
    glow = Image.new('L', (size, size), 0)
    ImageDraw.Draw(glow).ellipse(
        [centre[0] - radius, centre[1] - radius, centre[0] + radius, centre[1] + radius], fill=150)
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.07))
    image.paste(Image.new('RGB', (size, size), SUN), (0, 0), glow)
    draw = ImageDraw.Draw(image)

    # Rooftops along the bottom: left edge, width, height, as parts of the
    # icon. Lit windows are a fixed pattern, not random.
    for left, wide, tall in [(-0.02, 0.17, 0.30), (0.13, 0.12, 0.20), (0.23, 0.15, 0.36),
                             (0.62, 0.14, 0.33), (0.74, 0.12, 0.22), (0.84, 0.18, 0.31)]:
        x0, x1 = left * size, (left + wide) * size
        y0 = (1.0 - tall) * size
        draw.rectangle([x0, y0, x1, size], fill=SKYLINE)
        pane = 0.022 * size
        columns = int((x1 - x0 - pane) // (pane * 1.9))
        for row in range(4):
            for col in range(columns):
                if (row * 3 + col * 5 + int(left * 100)) % 4 == 0:
                    wx = x0 + pane * 0.9 + col * pane * 1.9
                    wy = y0 + pane * 1.2 + row * pane * 2.1
                    if 0 <= wx and wx + pane <= size:
                        draw.rectangle([wx, wy, wx + pane, wy + pane * 1.1], fill=WINDOW)
    return image


def courier_layer(size, courier, bust_width, head_centre):
    """The courier with a white sticker edge and a shadow, on transparency.

    [bust_width] is how much of the icon's width the bust spans, and
    [head_centre] where the middle of the face goes, both as parts of [size].
    """
    scale = bust_width * size / ((BUST_RIGHT - BUST_LEFT) * REDRAW)
    scaled = courier.resize(
        (round(courier.width * scale), round(courier.height * scale)), Image.LANCZOS)
    native = scale * REDRAW  # icon pixels per sprite pixel
    left = round(head_centre[0] * size - HEAD_CENTER_X * native)
    top = round(head_centre[1] * size - HEAD_CENTER_Y * native)

    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    shape = Image.new('L', (size, size), 0)
    shape.paste(scaled.getchannel('A'), (left, top))

    edge = shape.filter(ImageFilter.GaussianBlur(size * 0.012))
    edge = edge.point(lambda v: 255 if v > 40 else 0).filter(ImageFilter.GaussianBlur(size * 0.0015))
    shadow = edge.filter(ImageFilter.GaussianBlur(size * 0.016)).point(lambda v: int(v * 0.45))
    layer.paste(Image.new('RGBA', (size, size), (10, 12, 30, 255)),
                (0, round(size * 0.014)), shadow)
    layer.paste(Image.new('RGBA', (size, size), (255, 255, 255, 255)), (0, 0), edge)
    layer.alpha_composite(scaled, (left, top))
    return layer


def rounded(image, radius_part):
    size = image.width
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius_part * size, fill=255)
    out = image.convert('RGBA')
    out.putalpha(mask)
    return out


def build_masters():
    courier = redraw_sprite(SPRITE, REDRAW)
    background = sky(MASTER)

    # A tile: the face fills it and the shoulders run off the bottom.
    tile = background.convert('RGBA')
    tile.alpha_composite(courier_layer(MASTER, courier, 0.90, (0.49, 0.48)))

    # Launchers cut a maskable or adaptive icon to their own shape and only
    # promise the middle: a circle 80% of the width on the web, 66 of 108 dp
    # on Android. The face and fist sit inside the smaller of the two.
    safe = courier_layer(MASTER, courier, 0.60, (0.50, 0.47))
    maskable = background.convert('RGBA')
    maskable.alpha_composite(safe)
    return {
        'tile': tile.convert('RGB'),
        'maskable': maskable.convert('RGB'),
        'background': background,
        'foreground': safe,
    }


def scaled(image, size):
    return image.resize((size, size), Image.LANCZOS)


def write(image, *path):
    target = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    image.save(target, 'PNG', optimize=True)
    return target


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--preview', help='also write the 1024 px masters to this folder')
    args = parser.parse_args()

    masters = build_masters()
    tile, maskable = masters['tile'], masters['maskable']
    written = []

    # Web. The plain icons are a rounded tile; the maskable ones are square.
    written.append(write(rounded(scaled(tile, 48), 0.22), 'web', 'favicon.png'))
    for size in (192, 512):
        written.append(write(rounded(scaled(tile, size), 0.22), 'web', 'icons', 'Icon-%d.png' % size))
        written.append(write(scaled(maskable, size), 'web', 'icons', 'Icon-maskable-%d.png' % size))

    # Android. 48 dp launcher tile and the 108 dp adaptive layers.
    res = ('android', 'app', 'src', 'main', 'res')
    for density, times in (('mdpi', 1.0), ('hdpi', 1.5), ('xhdpi', 2.0), ('xxhdpi', 3.0),
                           ('xxxhdpi', 4.0)):
        folder = res + ('mipmap-' + density,)
        written.append(write(rounded(scaled(tile, round(48 * times)), 0.22),
                             *folder, 'ic_launcher.png'))
        written.append(write(scaled(masters['background'], round(108 * times)),
                             *folder, 'ic_launcher_background.png'))
        written.append(write(scaled(masters['foreground'], round(108 * times)),
                             *folder, 'ic_launcher_foreground.png'))

    # iOS: whatever the asset catalogue asks for, square and opaque.
    catalogue = ('ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    with open(os.path.join(ROOT, *catalogue, 'Contents.json'), encoding='utf-8') as handle:
        entries = json.load(handle)['images']
    for entry in entries:
        points = float(entry['size'].split('x')[0])
        pixels = round(points * int(entry['scale'].rstrip('x')))
        written.append(write(scaled(tile, pixels), *catalogue, entry['filename']))

    if args.preview:
        os.makedirs(args.preview, exist_ok=True)
        for name, image in masters.items():
            scaled(image, 1024).save(os.path.join(args.preview, name + '.png'))

    print('wrote %d icons' % len(set(written)))


if __name__ == '__main__':
    main()
