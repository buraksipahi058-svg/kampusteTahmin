import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Marka rengi: koyu yeşil (Material şeması bundan türetilir).
const brandSeed = Color(0xFF1B5E20);

/// Material şemasında olmayan uygulama renkleri: SSP (prestij) altını ve başarı yeşili.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.ssp,
    required this.sspContainer,
    required this.onSspContainer,
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
  });

  final Color ssp;
  final Color sspContainer;
  final Color onSspContainer;
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;

  static const light = AppColors(
    ssp: Color(0xFF9A6B00),
    sspContainer: Color(0xFFFFE8B3),
    onSspContainer: Color(0xFF3A2800),
    success: Color(0xFF1E7B34),
    successContainer: Color(0xFFCDEFD3),
    onSuccessContainer: Color(0xFF07380F),
  );

  static const dark = AppColors(
    ssp: Color(0xFFF2C14E),
    sspContainer: Color(0xFF4A3700),
    onSspContainer: Color(0xFFFFE8B3),
    success: Color(0xFF7DDB8E),
    successContainer: Color(0xFF0E4A1D),
    onSuccessContainer: Color(0xFFCDEFD3),
  );

  @override
  AppColors copyWith({
    Color? ssp,
    Color? sspContainer,
    Color? onSspContainer,
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
  }) => AppColors(
    ssp: ssp ?? this.ssp,
    sspContainer: sspContainer ?? this.sspContainer,
    onSspContainer: onSspContainer ?? this.onSspContainer,
    success: success ?? this.success,
    successContainer: successContainer ?? this.successContainer,
    onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
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
    );
  }
}

extension AppColorsOf on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
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

/// Açık ve karanlık tema. Yazı tipi sistemin; başlıklarda kalınlık ve sıkı harf aralığıyla hiyerarşi.
ThemeData buildAppTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: brandSeed, brightness: brightness);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final t = base.textTheme;
  TextStyle? heading(TextStyle? s, double tracking, FontWeight weight) =>
      s?.copyWith(fontWeight: weight, letterSpacing: tracking);

  final textTheme = t.copyWith(
    headlineLarge: heading(t.headlineLarge, -0.64, FontWeight.w700),
    headlineMedium: heading(t.headlineMedium, -0.56, FontWeight.w700),
    headlineSmall: heading(t.headlineSmall, -0.48, FontWeight.w700),
    titleLarge: heading(t.titleLarge, -0.44, FontWeight.w700),
    titleMedium: heading(t.titleMedium, -0.16, FontWeight.w600),
    titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );

  return base.copyWith(
    textTheme: textTheme,
    extensions: [brightness == Brightness.dark ? AppColors.dark : AppColors.light],
    // Başlık stili burada verilmez: tema yazı boyutlarını dile göre sonradan ekler (verilirse boyutsuz kalır).
    appBarTheme: const AppBarTheme(centerTitle: false, scrolledUnderElevation: 1),
    // Yükseltilmiş yüzey: düz kenarlık yerine yumuşak gölge; köşeler yuvarlak, içerik kırpılır.
    cardTheme: CardThemeData(
      elevation: brightness == Brightness.dark ? 0 : 1,
      color: brightness == Brightness.dark ? scheme.surfaceContainer : scheme.surfaceContainerLowest,
      shadowColor: scheme.shadow.withValues(alpha: 0.25),
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
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
    bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
    dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl))),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.6), space: 1),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radii.lg))),
    ),
  );
}
