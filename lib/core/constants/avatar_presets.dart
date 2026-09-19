/// Mirrors backend/src/constants/avatarPresets.js exactly — keep both in
/// sync if this set ever changes. Each key maps to a bundled cartoon
/// illustration (assets/avatars/) rather than a free-form/uploaded image,
/// so there's no upload/storage/moderation surface at all — same reasoning
/// as category icons/colors being curated, not free-form.
class AvatarPresets {
  AvatarPresets._();

  static const List<String> keys = [
    'avatar_01', 'avatar_02', 'avatar_03', 'avatar_04',
    'avatar_05', 'avatar_06', 'avatar_07', 'avatar_08',
    'avatar_09', 'avatar_10', 'avatar_11', 'avatar_12',
  ];

  static String assetFor(String key) => 'assets/avatars/$key.png';
}
