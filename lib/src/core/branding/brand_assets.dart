/// Brand raster logos. Replace PNGs on disk to refresh in-app marks; run
/// `dart run flutter_launcher_icons` after changing [logoOnGreenPng] only.
abstract final class BrandAssets {
  /// White/light mark — use on brand-green backgrounds only.
  static const String logoOnGreenPng = "assets/branding/app_brand.png";

  /// Green mark (#0F7A2C) — use on neutral/light/dark surfaces.
  static const String logoGreenPng = "assets/branding/app_brand_green.png";

  @Deprecated("Use logoPathFor or BrandLogo with BrandLogoBackground")
  static const String logoPng = logoOnGreenPng;
}

/// Whether the logo sits on a brand-green fill or a neutral surface.
enum BrandLogoBackground { onBrandGreen, onNeutralSurface }

/// Resolves the correct logo asset for contrast.
String brandLogoPathFor(BrandLogoBackground background) =>
    background == BrandLogoBackground.onBrandGreen
        ? BrandAssets.logoOnGreenPng
        : BrandAssets.logoGreenPng;
