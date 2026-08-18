import 'package:flutter/material.dart';

/// The app mark.
///
/// The artwork ships with its own dark field baked in, so it is shown as-is
/// behind rounded corners rather than being tinted or dropped onto a gradient.
/// either would fight the background it already has.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 56, this.radius});

  final double size;

  /// Corner radius. Defaults to the ~22% ratio Android and iOS use for icons,
  /// so the mark reads as an app icon at any size.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Balance Book',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius ?? size * 0.22),
        child: Image.asset(
          'assets/images/appicon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          // The source art is 367px square, so it is upscaled on large
          // displays; a plain coloured square is a calmer failure than a
          // broken-image glyph if the asset ever goes missing.
          errorBuilder: (context, _, _) => Container(
            width: size,
            height: size,
            color: const Color(0xFF1B2A5E),
            alignment: Alignment.center,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: size * 0.5,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
