import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/brand_logo.dart';
import '../core/design_tokens.dart';
import '../core/haptics.dart';
import '../core/icon_badge.dart';

/// Öğreticinin bir sayfası: üstte büyük rozet (ilk sayfada logo), başlık, kısa giriş ve maddeler.
class TutorialPage {
  const TutorialPage({this.icon, required this.title, required this.lead, this.items = const []});

  /// Boşsa logo gösterilir.
  final IconData? icon;
  final String title;
  final String lead;
  final List<TutorialItem> items;
}

class TutorialItem {
  const TutorialItem(this.icon, this.title, this.text, {this.tone = BadgeTone.neutral});

  final IconData icon;
  final String title;
  final String text;
  final BadgeTone tone;
}

/// Yeni başlayana oyunun kısaca anlatımı. Metinler ekranlardaki açıklamalarla aynı kurallar (ekonomi ayarı
/// değişirse "Günlük ödül" maddesi de güncellenir).
const tutorialPages = [
  TutorialPage(
    title: 'Hoş geldin!',
    lead: 'Kampüsündeki olayları tahmin et, okul arkadaşlarınla yarış, sıralamada yüksel.',
    items: [
      TutorialItem(
        Symbols.money_off_rounded,
        'Gerçek para yok',
        'Puanlar sanaldır: satın alınmaz, paraya çevrilmez ve kimseye gönderilmez.',
      ),
      TutorialItem(
        Symbols.school_rounded,
        'Okuluna özel',
        'Bahisler, oyunlar ve sıralama okulundaki öğrencilerle paylaşılır.',
      ),
    ],
  ),
  TutorialPage(
    icon: Symbols.mark_email_read_rounded,
    title: 'Önce okul mailini doğrula',
    lead: 'Okulundaki bahisleri, oyunları ve sıralamayı görmek için okul e-postanı doğrulaman gerekir.',
    items: [
      TutorialItem(
        Symbols.person_rounded,
        "Profil'den başla",
        'Profil sekmesinde "Okul mailini doğrula"ya dokun, okul adresine gelen kodu gir.',
      ),
    ],
  ),
  TutorialPage(
    icon: Symbols.toll_rounded,
    title: 'İki puan: SP ve SSP',
    lead: 'Her şey iki sanal puanla oynanır.',
    items: [
      TutorialItem(
        Symbols.toll_rounded,
        'SP · günlük puan',
        'Başlangıçta verilir; günlük ödül, görevler ve kazandığın tahminlerle artar. Sosyal bahis, günün '
            'tahmini, düello ve markette harcanır.',
      ),
      TutorialItem(
        Symbols.workspace_premium_rounded,
        'SSP · prestij puanı',
        'Yalnızca resmi okul etkinlikleri ve özel görevlerle kazanılır. Resmi bahislerde ve marketin özel '
            'vitrininde kullanılır.',
        tone: BadgeTone.gold,
      ),
    ],
  ),
  TutorialPage(
    icon: Symbols.how_to_vote_rounded,
    title: 'Bahisler',
    lead: 'Bahisler sekmesinde iki tür var.',
    items: [
      TutorialItem(
        Symbols.emoji_events_rounded,
        'Resmi',
        'Okulun açtığı etkinliklere SSP ile oynanır. Oran sabittir: kazanırsan yatırdığın × oran kadar SSP alırsın.',
        tone: BadgeTone.gold,
      ),
      TutorialItem(
        Symbols.groups_rounded,
        'Sosyal',
        'Okul arkadaşlarınla SP ile oynanır, kazananlar havuzu paylaşır. Sonucu hakem girer, katılanlar itiraz '
            'edebilir.',
      ),
    ],
  ),
  TutorialPage(
    icon: Symbols.sports_esports_rounded,
    title: 'Oyunlar',
    lead: 'Oyunlar sekmesinde her gün yapacak bir şey var.',
    items: [
      TutorialItem(
        Symbols.lightbulb_rounded,
        'Günün tahmini',
        "Evet ya da Hayır'a SP yatır; doğru bilenler havuzu paylaşır.",
      ),
      TutorialItem(
        Symbols.quiz_rounded,
        'Trivia düellosu',
        'Okulundan biriyle aynı soruları çöz, kazanan havuzu alır.',
      ),
      TutorialItem(
        Symbols.qr_code_2_rounded,
        'Kampüs görevleri',
        'Yemekhane, kütüphane, etkinlik: QR okut ya da fotoğraf çek, ödül kazan.',
      ),
      TutorialItem(
        Symbols.spellcheck_rounded,
        'Kampüs kelimesi',
        'Her gün kampüsle ilgili bir kelime: 6 hakta bul, ne kadar az hakta bulursan o kadar çok ödül.',
      ),
    ],
  ),
  TutorialPage(
    icon: Symbols.local_fire_department_rounded,
    title: 'Her gün gel, yüksel',
    lead: 'Düzenli oynadıkça ödüller büyür.',
    items: [
      TutorialItem(
        Symbols.featured_seasonal_and_gifts_rounded,
        'Günlük ödül',
        'Her gün ödülünü al, serin büyüsün; 7, 14 ve 30. günlerde bonus var.',
        tone: BadgeTone.gold,
      ),
      TutorialItem(
        Symbols.flag_rounded,
        'Görevler ve başarımlar',
        'Görevleri bitir, başarımları topla: ödül ve XP kazan, seviye atla.',
      ),
      TutorialItem(
        Symbols.storefront_rounded,
        'Market',
        'Yalnızca görünüm satar (unvan, rozet, çerçeve, isim rengi); kazanma şansını etkilemez.',
      ),
      TutorialItem(Symbols.leaderboard_rounded, 'Liderlik', 'Okulunda haftanın en isabetli tahmincileri.'),
    ],
  ),
];

/// "Nasıl oynanır": ilk girişte bir kez kendiliğinden (HomeShell), sonra Profil'den açılır. Kaydırarak ya da
/// "İleri" ile gezilir; "Atla", geri tuşu ve son sayfadaki "Başlayalım" kapatır.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, this.pages = tutorialPages});

  final List<TutorialPage> pages;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _controller = PageController();
  var _page = 0;

  bool get _last => _page == widget.pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    Haptics.light();
    context.pop();
  }

  void _next() {
    if (_last) return _close();
    // Sayfa ekranda yer değiştirir: ease-in-out; "animasyonları azalt"ta doğrudan geçer.
    if (Motion.reduced(context)) {
      _controller.jumpToPage(_page + 1);
    } else {
      _controller.nextPage(duration: Motion.enter, curve: Motion.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.pages.length;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          if (!_last) TextButton(onPressed: _close, child: const Text('Atla')),
          const SizedBox(width: Space.sm),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) {
                  Haptics.selection();
                  setState(() => _page = i);
                },
                children: [for (final p in widget.pages) _PageBody(page: p)],
              ),
            ),
            const SizedBox(height: Space.md),
            _Dots(count: count, index: _page),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.xl),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _next, child: Text(_last ? 'Başlayalım' : 'İleri')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.page});

  final TutorialPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.sm, Space.xl, Space.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              if (page.icon case final icon?) IconBadge(icon: icon, size: 88) else const BrandLogo(width: 200),
              const SizedBox(height: Space.xl),
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: Space.sm),
              Text(
                page.lead,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: Space.xl),
              for (final item in page.items) ...[_ItemRow(item: item), const SizedBox(height: Space.lg)],
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final TutorialItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconBadge(icon: item.icon, size: 40, tone: item.tone),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(item.text, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

/// Sayfa göstergesi: etkin sayfa uzun, mor; ekran okuyucu "Sayfa 2 / 6" okur.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = Motion.reduced(context) ? Duration.zero : Motion.fast;
    return Semantics(
      label: 'Sayfa ${index + 1} / $count',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: duration,
                curve: Motion.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == index ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == index ? scheme.primary : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
