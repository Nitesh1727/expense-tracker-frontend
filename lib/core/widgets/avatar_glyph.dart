import 'package:flutter/material.dart';
import '../constants/avatar_presets.dart';

/// The content inside a profile avatar circle — the user's chosen avatar
/// illustration if they've picked one, else their name's first letter, else
/// a generic person icon. Used by both ProfileScreen's large gradient
/// avatar and RootShell's small flat one, which have different surrounding
/// decoration but the same fallback logic for what goes inside.
class AvatarGlyph extends StatelessWidget {
  final String? avatar;
  final String? name;
  final double size;
  final Color color;

  const AvatarGlyph({super.key, this.avatar, this.name, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    if (avatar != null) {
      // cacheWidth avoids decoding the full source resolution just to show
      // it this small — see WelcomeScreen's logo for the same reasoning
      // (an undersized cacheWidth caused a real, measured jank there).
      final cacheSize = (size * MediaQuery.of(context).devicePixelRatio).round();
      return ClipOval(
        child: Image.asset(
          AvatarPresets.assetFor(avatar!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: cacheSize,
          cacheHeight: cacheSize,
        ),
      );
    }
    final initial = (name?.isNotEmpty ?? false) ? name![0].toUpperCase() : null;
    if (initial != null) {
      return Text(initial, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: size * 0.7));
    }
    return Icon(Icons.person_outline, color: color, size: size * 0.75);
  }
}
