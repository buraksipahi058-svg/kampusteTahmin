import 'package:flutter/material.dart';

/// Uygulamanın logosu (yeşil zeminde "K" monogramı ve altın ödül noktası; uygulama ikonuyla aynı,
/// `tool/make_icon.py`). Giriş ve yükleniyor ekranlarında, uygulama adının üstünde.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/brand/logo.png',
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
    semanticLabel: 'KampüsBet logosu',
  );
}
