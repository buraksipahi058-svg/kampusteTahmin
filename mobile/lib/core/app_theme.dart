import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Marka rengi: canlı mor (fütüristik; Material şeması bundan türetilir, koyu temada elle ayarlanır).
const brandSeed = Color(0xFF7C3AED);

/// İkinci vurgu: neon camgöbeği (degrade ve ışıltılarda morun karşısında).
const brandAccent = Color(0xFF22D3EE);

/// Material şemasında olmayan uygulama renkleri: SSP (prestij) altını, başarı yeşili, neon vurgu ve ışıltı.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.ssp,
    required this.sspContainer,
    required this.onSspContainer,
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.accent,
    required this.glow,
  });

  final Color ssp;
  final Color sspContainer;
  final Color onSspContainer;
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;

  /// Neon camgöbeği: degradenin ikinci ucu, seçili vurgu.
  final Color accent;

  /// Öne çıkan öğenin (seçilen şık, bugünün ödülü, kendi satırın) çevresindeki ışıltı.
  final Color glow;

  /// Marka degradesi: mor → camgöbeği (rozet, logo, vurgulu yüzey).
  List<Color> get brandGradient => [const Color(0xFF8B5CF6), accent];

  static const light = AppColors(
    ssp: Color(0xFFA16207),
    sspContainer: Color(0xFFFEF3C7),
    onSspContainer: Color(0xFF422006),
    success: Color(0xFF047857),
    successContainer: Color(0xFFD1FAE5),
    onSuccessContainer: Color(0xFF022C22),
    accent: Color(0xFF0891B2),
    glow: Color(0x557C3AED),
  );

  static const dark = AppColors(
    ssp: Color(0xFFFBBF24),
    sspContainer: Color(0xFF3B2A05),
    onSspContainer: Color(0xFFFDE68A),
    success: Color(0xFF34D399),
    successContainer: Color(0xFF0B3B2C),
    onSuccessContainer: Color(0xFFA7F3D0),
    accent: brandAccent,
    glow: Color(0x668B5CF6),
  );

  @override
  AppColors copyWith({
    Color? ssp,
    Color? sspContainer,
    Color? onSspContainer,
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? accent,
    Color? glow,
  }) => AppColors(
    ssp: ssp ?? this.ssp,
    sspContainer: sspContainer ?? this.sspContainer,
    onSspContainer: onSspContainer ?? this.onSspContainer,
    success: success ?? this.success,
    successContainer: successContainer ?? this.successContainer,
    onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
    accent: accent ?? this.accent,
    glow: glow ?? this.glow,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      ssp: Color.lerp(ssp, other.ssp, t)!,
      sspContainer: Color.lerp(sspContainer, other.sspContainer, t)!,
      onSspContainer: Color.lerp(onSspContainer, other.onSspContainer, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
    );
  }
}

extension AppColorsOf on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>() ?? AppColors.dark;
}

/// Değişen sayılar (bakiye, oran, havuz, sayaç) sabit genişlikli rakamla: değişince satır oynamaz.
TextStyle? tabular(TextStyle? style) => style?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

/// Sunucudan gelen renk (ör. kozmetik isim rengi) zeminde okunmuyorsa açılır / koyulaştırılır (en az 3:1).
Color readableOn(Color color, Color background) {
  const minRatio = 3.0;
  double ratio(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  if (ratio(color, background) >= minRatio) return color;
  final darkBackground = background.computeLuminance() < 0.5;
  final hsl = HSLColor.fromColor(color);
  for (var step = 1; step <= 20; step++) {
    final l = darkBackground ? hsl.lightness + step * 0.04 : hsl.lightness - step * 0.04;
    final c = hsl.withLightness(l.clamp(0.0, 1.0)).toColor();
    if (ratio(c, background) >= minRatio) return c;
  }
  return darkBackground ? Colors.white : Colors.black;
}

/// Kozmetik isim rengi (sunucudan): açık ve karanlık temada zeminde okunur hâle getirilir.
Color? readableNameColor(BuildContext context, Color? color) =>
    color == null ? null : readableOn(color, Theme.of(context).colorScheme.surface);

/// Koyu şema elle: gece moru zemin, katman katman mor paneller, canlı mor ana renk, neon camgöbeği ikinci vurgu.
ColorScheme _darkScheme() {
  final base = ColorScheme.fromSeed(
    seedColor: brandSeed,
    brightness: Brightness.dark,
    dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
  );
  return base.copyWith(
    surface: const Color(0xFF0B0914),
    surfaceDim: const Color(0xFF0B0914),
    surfaceBright: const Color(0xFF2A2547),
    surfaceContainerLowest: const Color(0xFF07060E),
    surfaceContainerLow: const Color(0xFF110E1F),
    surfaceContainer: const Color(0xFF161328),
    surfaceContainerHigh: const Color(0xFF1E1A35),
    surfaceContainerHighest: const Color(0xFF272243),
    onSurface: const Color(0xFFEEEAFF),
    onSurfaceVariant: const Color(0xFFB8B1DC),
    outline: const Color(0xFF5B5384),
    outlineVariant: const Color(0xFF2F2A4E),
    primary: const Color(0xFFA78BFA),
    onPrimary: const Color(0xFF1C0B44),
    primaryContainer: const Color(0xFF4C1D95),
    onPrimaryContainer: const Color(0xFFEDE4FF),
    secondary: brandAccent,
    onSecondary: const Color(0xFF00262F),
    // Seçili parça / çip / kendi satırın kabı: camgöbeği değil mor ton (bütünlük); camgöbeği yalnızca vurgu.
    secondaryContainer: const Color(0xFF2E2266),
    onSecondaryContainer: const Color(0xFFE2DAFF),
    tertiary: const Color(0xFFF0ABFC),
    onTertiary: const Color(0xFF3B0A40),
    tertiaryContainer: const Color(0xFF5B1D63),
    onTertiaryContainer: const Color(0xFFFCE0FF),
    inverseSurface: const Color(0xFFEEEAFF),
    onInverseSurface: const Color(0xFF161328),
    inversePrimary: const Color(0xFF6D28D9),
    surfaceTint: Colors.transparent,
  );
}

/// Açık ve karanlık tema (uygulama koyu açılır; açık tema da mor). Yazı tipi sistemin; başlıklarda kalınlık ve sıkı
/// harf aralığıyla hiyerarşi. Kartlar ince kenarlıklı panel.
ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = dark
      ? _darkScheme()
      : ColorScheme.fromSeed(
          seedColor: brandSeed,
          brightness: Brightness.light,
          dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
        ).copyWith(secondary: AppColors.light.accent, surfaceTint: Colors.transparent);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final t = base.textTheme;
  TextStyle? heading(TextStyle? s, double tracking, FontWeight weight) =>
      s?.copyWith(fontWeight: weight, letterSpacing: tracking);

  final textTheme = t.copyWith(
    headlineLarge: heading(t.headlineLarge, -0.64, FontWeight.w800),
    headlineMedium: heading(t.headlineMedium, -0.56, FontWeight.w800),
    headlineSmall: heading(t.headlineSmall, -0.48, FontWeight.w700),
    titleLarge: heading(t.titleLarge, -0.44, FontWeight.w700),
    titleMedium: heading(t.titleMedium, -0.16, FontWeight.w600),
    titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
  );
  final panelBorder = BorderSide(color: scheme.outlineVariant.withValues(alpha: dark ? 0.9 : 0.7));

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [dark ? AppColors.dark : AppColors.light],
    // Başlık stili burada verilmez: tema yazı boyutlarını dile göre sonradan ekler (verilirse boyutsuz kalır).
    appBarTheme: AppBarTheme(
      centerTitle: false,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
    ),
    // Panel: ince kenarlık, gölgesiz (koyu zeminde gölge görünmez); köşeler yuvarlak, içerik kırpılır.
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? scheme.surfaceContainerLow : scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg), side: panelBorder),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primaryContainer,
      surfaceTintColor: Colors.transparent,
    ),
    // Bütün girdiler aynı: dış çizgili, yuvarlak köşe (pencerelerdekiler de).
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
    ),
    // Alt sayfalar sürükleme tutamaklı: aşağı çekince kapanır.
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl), side: panelBorder),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.8), space: 1),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radii.lg))),
    ),
  );
}
