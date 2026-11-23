import 'package:flutter/material.dart';

import 'app_info.dart';

/// Uygulamanın logosu: kep + "K" + mor oynat üçgeni ve altında "kampusbet" yazısı (kullanıcının verdiği logo,
/// `tool/brand/kampusbet_logo.webp`'ten `tool/make_icon.py` ile saydam zemine çıkarıldı). Giriş ve yükleniyor
/// ekranlarında; uygulama adını da taşıdığı için yanında ayrıca ad yazılmaz. Uygulama ikonu yalnızca işaret.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.width = 200});

  final double width;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/brand/logo.png',
    width: width,
    filterQuality: FilterQuality.medium,
    semanticLabel: AppInfo.name,
  );
}
