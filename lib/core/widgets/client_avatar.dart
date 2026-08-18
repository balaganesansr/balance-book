import 'package:flutter/material.dart';

import '../../models/client.dart';
import '../theme/app_colors.dart';

/// Coloured initials disc for a client.
///
/// When no colour has been chosen, one is derived from the name, so every
/// client looks deliberate and stays recognisable between sessions.
class ClientAvatar extends StatelessWidget {
  const ClientAvatar({
    super.key,
    required this.name,
    this.colorHex,
    this.size = 44,
    this.isFavorite = false,
  });

  ClientAvatar.of(
    Client client, {
    super.key,
    this.size = 44,
    bool showFavorite = false,
  }) : name = client.name,
       colorHex = client.avatarColor,
       isFavorite = showFavorite && client.isFavorite;

  final String name;
  final String? colorHex;
  final double size;
  final bool isFavorite;

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final only = parts.first;
      return only.substring(0, only.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hex = (colorHex == null || colorHex!.isEmpty)
        ? AvatarPalette.forSeed(name)
        : colorHex!;
    final base = AvatarPalette.parse(hex);

    final disc = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: base.withValues(alpha: 0.28)),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          color: base,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
          letterSpacing: 0.2,
        ),
      ),
    );

    if (!isFavorite) {
      return Semantics(label: name, child: disc);
    }

    return Semantics(
      label: '$name, favourite',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          disc,
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: context.colors.surfaceRaised,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star_rounded,
                size: size * 0.32,
                color: const Color(0xFFF59E0B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
