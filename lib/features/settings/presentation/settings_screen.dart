import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_bar_title.dart';
import '../../../core/widgets/picker_dot.dart';
import '../domain/app_settings.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle('Display')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Appearance', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  for (final mode in ThemeMode.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _ChoiceCard(
                          label: mode.label,
                          selected: settings.themeMode == mode,
                          onTap: () => ref.read(settingsControllerProvider.notifier).setThemeMode(mode),
                          preview: Icon(
                            switch (mode) {
                              ThemeMode.system => Icons.brightness_auto_outlined,
                              ThemeMode.light => Icons.light_mode_outlined,
                              ThemeMode.dark => Icons.dark_mode_outlined,
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Accent color',
            style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final option in AccentColorOption.values)
                    PickerDot(
                      selected: settings.accentColor == option,
                      onTap: () => ref.read(settingsControllerProvider.notifier).setAccentColor(option),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // Always previewed in the light-mode tone — it's the more
                          // saturated, recognizable version of the hue regardless of
                          // which theme mode is currently active.
                          color: option.light,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Text size', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  for (final option in TextSizeOption.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _ChoiceCard(
                          label: option.label,
                          selected: settings.textSize == option,
                          onTap: () => ref.read(settingsControllerProvider.notifier).setTextSize(option),
                          preview: Text('Aa', style: TextStyle(fontSize: 16 * option.scale, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Font', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                for (final option in AppFontOption.values) ...[
                  RadioListTile<AppFontOption>(
                    value: option,
                    groupValue: settings.font,
                    onChanged: (value) {
                      if (value != null) ref.read(settingsControllerProvider.notifier).setFont(value);
                    },
                    // GoogleFonts.getFont, not a plain TextStyle(fontFamily: ...) — a raw
                    // TextStyle only sets the family *name* Flutter looks for, it doesn't
                    // load the font, so every row silently fell back to the same default
                    // typeface instead of actually previewing its own font.
                    title: Text(
                      option.fontFamily,
                      style: GoogleFonts.getFont(
                        option.fontFamily,
                        fontSize: 16,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      'The quick brown fox jumps',
                      style: GoogleFonts.getFont(option.fontFamily, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                  if (option != AppFontOption.values.last) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget preview;

  const _ChoiceCard({required this.label, required this.selected, required this.onTap, required this.preview});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? colorScheme.primary : colorScheme.outline),
        ),
        child: Column(
          children: [
            preview,
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
