import "package:flutter/material.dart";

export "brand_assets.dart" show BrandAssets, BrandLogoBackground, brandLogoPathFor;
import "brand_assets.dart";

/// Brand mark with correct contrast for the parent background.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    required this.height,
    this.background = BrandLogoBackground.onNeutralSurface,
    this.fit = BoxFit.contain,
  });

  final double height;
  final BrandLogoBackground background;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      brandLogoPathFor(background),
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
    );
  }
}
