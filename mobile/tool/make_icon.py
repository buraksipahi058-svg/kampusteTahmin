"""KampüsBet uygulama ikonu ve logosu (fütüristik mor): mor → gece moru degrade zemin, sağ altta camgöbeği ışık
hüzmesi, beyaz yuvarlak uçlu "K" monogramı, ışıldayan neon camgöbeği nokta.
4 kat büyük çizilip küçültülür (pürüzsüz kenar). Çıktılar mobile/assets/brand/ altına.
Kullanım (mobile/): python tool/make_icon.py && dart run flutter_launcher_icons (sonra ios/Runner.xcodeproj/project.pbxproj değişikliğini geri al: aracın bilinen hatası)."""
import os
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'brand')
os.makedirs(OUT, exist_ok=True)
S = 4096            # çizim tuvali (1024 x 4)
TOP = (139, 92, 246)           # #8B5CF6 canlı mor
BOTTOM = (30, 12, 74)          # #1E0C4A gece moru
ACCENT = (34, 211, 238)        # #22D3EE neon camgöbeği
WHITE = (255, 255, 255)


def gradient(size):
    img = Image.new('RGB', (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))      # sol üstten sağ alta
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM))
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
    # Neon noktanın ışıltısı önce (monogramın altında kalır, beyaz kolu boyamaz).
    cx, cy = P(716, 252)
    r = 46 * k
    halo = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse([cx - r * 1.9, cy - r * 1.9, cx + r * 1.9, cy + r * 1.9], fill=ACCENT + (150,))
    img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(radius=round(34 * k))))
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
    # Neon nokta: üst kolun ucunun sağ üstünde.
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=ACCENT + (255,))
    return img


def glow_bg(size):
    """Degrade zemin + sağ altta camgöbeği ışık hüzmesi (fütüristik derinlik)."""
    img = gradient(256).resize((size, size), Image.BICUBIC).convert('RGBA')
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    c, r = size * 0.95, size * 0.55
    gd.ellipse([c - r, c - r, c + r, c + r], fill=ACCENT + (70,))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(radius=size // 10)))
    return img


def rounded_mask(size, radius):
    m = Image.new('L', (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m


# 1) Tam ikon (iOS ve eski Android): kare, saydamlık yok (iOS köşeyi kendisi yuvarlar).
bg = glow_bg(S)
full = bg.copy()
full.alpha_composite(mark())
full.convert('RGB').resize((1024, 1024), Image.LANCZOS).save(os.path.join(OUT, 'app_icon.png'))

# 2) Android uyarlanabilir ikon ön katmanı: saydam, tam ölçek (flutter_launcher_icons %16 içeriden yerleştirir).
fg = mark(scale=1.0)
fg.resize((1024, 1024), Image.LANCZOS).save(os.path.join(OUT, 'app_icon_foreground.png'))

# 3) Uyarlanabilir ikon arka katmanı: degrade.
glow_bg(1024).convert('RGB').save(os.path.join(OUT, 'app_icon_background.png'))

# 4) Uygulama içi logo: yuvarlatılmış kare (512), saydam köşeler.
logo = full.copy()
logo.putalpha(rounded_mask(S, round(S * 0.23)))
logo.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, 'logo.png'))
print('ok', os.listdir(OUT))
