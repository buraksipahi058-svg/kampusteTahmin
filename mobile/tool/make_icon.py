"""KampüsBet logosu ve uygulama ikonu, kullanıcının verdiği logodan (tool/brand/kampusbet_logo.webp: koyu zeminde
beyaz kep + "K" + mor oynat üçgeni, altında "kampusbet" yazısı).

Kaynak düz renkli (beyaz, mor) ve küçük olduğundan: zeminden saydamlık ve mor oranı çıkarılır, ikisi büyütülüp
kenarları keskinleştirilir, hedef boyuta küçültülür (pürüzsüz, bulanık olmayan kenar). Çıktılar:
  mobile/assets/brand/  logo.png (işaret + yazı, saydam), app_icon.png (koyu zeminde işaret),
                        app_icon_foreground.png / app_icon_background.png (Android uyarlanabilir ikon)
  admin/public/         logo.png (işaret, saydam), logo-full.png (işaret + yazı), icon.png; admin/src/app/favicon.ico
Kullanım (mobile/): python tool/make_icon.py && dart run flutter_launcher_icons
(sonra ios/Runner.xcodeproj/project.pbxproj değişikliğini geri al: aracın bilinen hatası)."""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'brand', 'kampusbet_logo.webp')
MOBILE = os.path.join(HERE, '..', 'assets', 'brand')
ADMIN = os.path.join(HERE, '..', '..', 'admin')

BG = (8, 7, 12)              # kaynağın zemini #08070C
WHITE = (246, 245, 245)
PURPLE = (122, 79, 241)      # kaynağın moru #7A4FF1
BG_MAX, FG_MAX = 16, 238     # en parlak kanal: zemin ~12, beyaz / mor ~240
SUPER = 4                    # hedefin 4 katında keskinleştirilip küçültülür


def clamp(v):
    return 0.0 if v < 0 else 1.0 if v > 1 else v


def layers(src, box):
    """Kırpılan bölgeden saydamlık (A) ve mor oranı (P) katmanları (L kipinde)."""
    crop = src.crop(box)
    w, h = crop.size
    a_img, p_img = Image.new('L', (w, h)), Image.new('L', (w, h))
    px, pa, pp = crop.load(), a_img.load(), p_img.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            a = clamp((max(r, g, b) - BG_MAX) / (FG_MAX - BG_MAX))
            pa[x, y] = round(a * 255)
            if a > 0.05:
                # Zeminle karışmış kenar renginden asıl rengi çöz: c = a * fg + (1 - a) * bg.
                fr = (r - (1 - a) * BG[0]) / a
                fb = (b - (1 - a) * BG[2]) / a
                pp[x, y] = round(clamp((fb - fr) / (PURPLE[2] - PURPLE[0])) * 255)
    return a_img, p_img


def sharp(img, lo, hi):
    """Büyütmenin yumuşattığı kenarı daralt (lo altı 0, hi üstü 255)."""
    return img.point(lambda v: 0 if v <= lo else 255 if v >= hi else round((v - lo) / (hi - lo) * 255))


def render(src, box, width):
    """Kutudaki çizimi saydam zeminde `width` px genişliğinde RGBA olarak çiz."""
    a_img, p_img = layers(src, box)
    w, h = a_img.size
    big = (width * SUPER, round(h * width * SUPER / w))
    a_big = sharp(a_img.resize(big, Image.LANCZOS), 90, 165)
    p_big = sharp(p_img.resize(big, Image.LANCZOS), 100, 155)
    color = Image.composite(Image.new('RGB', big, PURPLE), Image.new('RGB', big, WHITE), p_big)
    rgba = color.copy()
    rgba.putalpha(a_big)
    target = (width, round(big[1] / SUPER))
    return rgba.convert('RGBa').resize(target, Image.LANCZOS).convert('RGBA')


def bbox(src, rows):
    """Satır aralığındaki çizimin sınır kutusu (8 px pay)."""
    y0, y1 = rows
    region = src.crop((0, y0, src.width, y1)).convert('L').point(lambda v: 255 if v > 60 else 0)
    x0, t, x1, b = region.getbbox()
    return (x0 - 8, y0 + t - 8, x1 + 8, y0 + b + 8)


def place(canvas_size, art, width_ratio, bg=None):
    """Çizimi kare tuvalin ortasına, genişliği tuvalin `width_ratio` katı olacak biçimde koy."""
    canvas = Image.new('RGBA', (canvas_size, canvas_size), bg + (255,) if bg else (0, 0, 0, 0))
    w = round(canvas_size * width_ratio)
    scaled = art.resize((w, round(art.height * w / art.width)), Image.LANCZOS) if art.width != w else art
    canvas.alpha_composite(scaled, ((canvas_size - scaled.width) // 2, (canvas_size - scaled.height) // 2))
    return canvas


def main():
    src = Image.open(SRC).convert('RGB')
    # Kaynakta işaret ile yazı arasında boş satırlar var: işaret üstte, yazı altta.
    gray = src.convert('L').point(lambda v: 255 if v > 60 else 0)
    full = gray.getbbox()
    rows = [any(gray.getpixel((x, y)) for x in range(full[0], full[2], 2)) for y in range(full[1], full[3])]
    gap = next(i for i, filled in enumerate(rows) if not filled) + full[1]
    mark_box = bbox(src, (full[1], gap))
    lockup_box = (full[0] - 8, full[1] - 8, full[2] + 8, full[3] + 8)

    mark = render(src, mark_box, 1024)
    lockup = render(src, lockup_box, 1200)

    os.makedirs(MOBILE, exist_ok=True)
    lockup.save(os.path.join(MOBILE, 'logo.png'))
    # iOS / eski Android: koyu kare zemin, işaret ortada (köşe yuvarlatmasına pay bırakılır).
    icon = place(1024, mark, 0.62, BG)
    icon.convert('RGB').save(os.path.join(MOBILE, 'app_icon.png'))
    # Uyarlanabilir ikon: maske daire de olabilir; işaret güvenli bölgenin (ortadaki %61) içinde.
    place(1024, mark, 0.50).save(os.path.join(MOBILE, 'app_icon_foreground.png'))
    Image.new('RGB', (1024, 1024), BG).save(os.path.join(MOBILE, 'app_icon_background.png'))

    public = os.path.join(ADMIN, 'public')
    os.makedirs(public, exist_ok=True)
    mark.resize((256, round(mark.height * 256 / mark.width)), Image.LANCZOS).save(os.path.join(public, 'logo.png'))
    lockup.resize((800, round(lockup.height * 800 / lockup.width)), Image.LANCZOS).save(
        os.path.join(public, 'logo-full.png'))
    small_icon = icon.convert('RGB').resize((512, 512), Image.LANCZOS)
    small_icon.save(os.path.join(public, 'icon.png'))
    # Next (Turbopack) ICO içindeki PNG'yi çözemiyor: BMP biçiminde, saydamlık kanallı yazılır.
    small_icon.convert('RGBA').save(
        os.path.join(ADMIN, 'src', 'app', 'favicon.ico'), sizes=[(16, 16), (32, 32), (48, 48)], bitmap_format='bmp')
    print('mark', mark.size, 'lockup', lockup.size)


if __name__ == '__main__':
    main()
