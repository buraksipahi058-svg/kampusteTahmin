"""KampüsBet uygulama ikonu ve logosu: yeşil degrade zemin, beyaz yuvarlak uçlu "K" monogramı, altın ödül noktası.
4 kat büyük çizilip küçültülür (pürüzsüz kenar). Çıktılar mobile/assets/brand/ altına.
Kullanım (mobile/): python tool/make_icon.py && dart run flutter_launcher_icons (sonra ios/Runner.xcodeproj/project.pbxproj değişikliğini geri al: aracın bilinen hatası)."""
import os
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'brand')
os.makedirs(OUT, exist_ok=True)
S = 4096            # çizim tuvali (1024 x 4)
GREEN_TOP = (46, 125, 50)      # #2E7D32
GREEN_BOTTOM = (20, 75, 24)    # #144B18 (marka #1B5E20'ye yakın, biraz koyu)
GOLD = (242, 193, 78)          # #F2C14E (SSP altını)
WHITE = (255, 255, 255)


def gradient(size):
    img = Image.new('RGB', (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))      # sol üstten sağ alta
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(GREEN_TOP, GREEN_BOTTOM))
    return img


def stroke(d, p, q, w, fill):
    d.line([p, q], fill=fill, width=w)
    r = w / 2
    for (x, y) in (p, q):
        d.ellipse([x - r, y - r, x + r, y + r], fill=fill)


def mark(scale=1.0, offset=(0, 0)):
    """Saydam zeminde monogram (S x S). scale: 1024'lük koordinatların çarpanı."""
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    k = S / 1024 * scale
    ox = S / 2 * (1 - scale) + offset[0] * S / 1024
    oy = S / 2 * (1 - scale) + offset[1] * S / 1024

    def P(x, y):
        return (ox + x * k, oy + y * k)

    w = round(96 * k)
    stem_top, stem_bottom = P(392, 300), P(392, 724)
    joint = P(404, 548)
    upper_end = P(624, 318)
    lower_start = P(486, 462)
    lower_end = P(640, 712)
    # Gölge (hafif, aşağı): monograma derinlik.
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sh = round(14 * k)
    for p, q in ((stem_top, stem_bottom), (joint, upper_end), (lower_start, lower_end)):
        stroke(sd, (p[0], p[1] + sh), (q[0], q[1] + sh), w, (0, 0, 0, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=round(18 * k)))
    img.alpha_composite(shadow)
    d = ImageDraw.Draw(img)
    for p, q in ((stem_top, stem_bottom), (joint, upper_end), (lower_start, lower_end)):
        stroke(d, p, q, w, WHITE + (255,))
    # Altın ödül noktası: üst kolun ucunun sağ üstünde.
    cx, cy = P(716, 252)
    r = 46 * k
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=GOLD + (255,))
    return img


def rounded_mask(size, radius):
    m = Image.new('L', (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m


# 1) Tam ikon (iOS ve eski Android): kare, saydamlık yok (iOS köşeyi kendisi yuvarlar).
bg = gradient(1024).resize((S, S), Image.BICUBIC).convert('RGBA')
full = bg.copy()
full.alpha_composite(mark())
full.convert('RGB').resize((1024, 1024), Image.LANCZOS).save(os.path.join(OUT, 'app_icon.png'))

# 2) Android uyarlanabilir ikon ön katmanı: saydam, tam ölçek (flutter_launcher_icons %16 içeriden yerleştirir).
fg = mark(scale=1.0)
fg.resize((1024, 1024), Image.LANCZOS).save(os.path.join(OUT, 'app_icon_foreground.png'))

# 3) Uyarlanabilir ikon arka katmanı: degrade.
gradient(1024).save(os.path.join(OUT, 'app_icon_background.png'))

# 4) Uygulama içi logo: yuvarlatılmış kare (512), saydam köşeler.
logo = full.copy()
logo.putalpha(rounded_mask(S, round(S * 0.23)))
logo.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, 'logo.png'))
print('ok', os.listdir(OUT))
