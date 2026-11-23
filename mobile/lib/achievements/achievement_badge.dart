import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'achievements_data.dart';

/// Başarımın ikonu: önce başarıma özel, yoksa (admin'in yeni eklediği) kategorinin ikonu. Veritabanındaki emoji
/// kullanılmaz: bütün rozetler aynı ikon ailesinden (Material Symbols Rounded).
IconData achievementIcon({String? key, String? category}) =>
    _byKey[key] ??
    switch (category) {
      'prediction' => Symbols.lightbulb_rounded,
      'streak' => Symbols.local_fire_department_rounded,
      'duel' => Symbols.swords_rounded,
      'social' => Symbols.groups_rounded,
      'loyalty' => Symbols.calendar_month_rounded,
      'progress' => Symbols.trending_up_rounded,
      'secret' => Symbols.auto_awesome_rounded,
      _ => Symbols.emoji_events_rounded,
    };

const _byKey = <String, IconData>{
  'kampuslu': Symbols.school_rounded,
  'ilk_tahmin': Symbols.lightbulb_rounded,
  'tahminci': Symbols.psychology_rounded,
  'mudavim': Symbols.event_repeat_rounded,
  'keskin_goz': Symbols.visibility_rounded,
  'bilge': Symbols.psychology_alt_rounded,
  'muneccim': Symbols.auto_awesome_rounded,
  'isiniyor': Symbols.local_fire_department_rounded,
  'alev_aldi': Symbols.whatshot_rounded,
  'durdurulamaz': Symbols.bolt_rounded,
  'meydan_okuyan': Symbols.swords_rounded,
  'duellocu': Symbols.sports_kabaddi_rounded,
  'bilgi_kupu': Symbols.quiz_rounded,
  'kusursuz': Symbols.stars_rounded,
  'ortaya_atan': Symbols.campaign_rounded,
  'adil_hakem': Symbols.gavel_rounded,
  'turnuva_ruhu': Symbols.emoji_events_rounded,
  'sadik': Symbols.calendar_month_rounded,
  'vazgecilmez': Symbols.event_available_rounded,
  'gorev_adami': Symbols.flag_rounded,
  'koleksiyoncu': Symbols.inventory_2_rounded,
  'yukselen': Symbols.trending_up_rounded,
  'efsane': Symbols.military_tech_rounded,
  'karda': Symbols.savings_rounded,
  'ters_kose': Symbols.rocket_launch_rounded,
};

/// Başarım rozeti: kademe renginde (bronz / gümüş / altın) halka ve hafif zemin, ortada dolu ikon. Kazanılmamışsa
/// gri ve çizgi ikon; gizli ve kazanılmamışsa kilit.
class AchievementBadge extends StatelessWidget {
  const AchievementBadge({
    super.key,
    required this.tier,
    this.achievementKey,
    this.category,
    this.earned = true,
    this.masked = false,
    this.size = 48,
  });

  final int tier;
  final String? achievementKey;
  final String? category;
  final bool earned;
  final bool masked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = earned ? tierColor(tier) : scheme.outline;
    final icon = masked ? Symbols.lock_rounded : achievementIcon(key: achievementKey, category: category);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: earned ? color.withValues(alpha: 0.16) : scheme.surfaceContainerHigh,
        border: Border.all(color: color, width: size >= 44 ? 2.5 : 2),
      ),
      child: Icon(icon, size: size * 0.5, fill: earned ? 1 : 0, color: color),
    );
  }
}
