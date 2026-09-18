import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// A vertically swipeable amount card cycling between periods (e.g. Today/
/// This week/This month on Home) — swiping past the last option wraps back
/// around to the first rather than stopping, and vice versa.
///
/// Went through a translucent frosted-glass version first, which the user
/// correctly called out as barely distinguishable from the page background —
/// backdrop blur only reads as "glass" over a detailed/colorful background;
/// against this app's flat ivory/charcoal page color it has nothing to blur,
/// so the alpha-tinted surface just looked like a slightly-different flat
/// color. This version instead uses a bold gradient built from the app's own
/// accent color (whatever the user picked in Settings → Appearance) — a
/// solid, unmistakable "hero stat card" in the style of Cash App/Revolut/
/// Apple Wallet's primary balance card — plus a colored ambient shadow and a
/// thin light-catching rim, rather than a low-contrast neutral surface.
///
/// - `viewportFraction` < 1 so the next/previous card visibly peeks in at
///   the top/bottom edge — a physical hint that there's more to swipe to.
///   No arrow icons on top of it (tried that; the user didn't want them) —
///   the peeking card alone reads as an affordance without extra chrome.
/// - Each "page" is the whole card (gradient, border, shadow), not a static
///   frame with only its inner text swapping — so the entire tile visibly
///   slides, not just its content.
/// - A brief one-time nudge-and-settle animation shortly after this widget
///   first appears, since nothing about a plain card otherwise suggests
///   it's interactive until a user stumbles onto the gesture by accident.
///
/// Every option's amount must already be available via [amountFor] (not
/// fetched lazily per swipe) so a swipe never shows a loading flash — see
/// homeSummaryProvider, which fetches all periods in parallel up front.
class SwipeableAmountTile<T> extends StatefulWidget {
  final List<(T value, String label)> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T value) amountFor;

  const SwipeableAmountTile({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.amountFor,
  });

  @override
  State<SwipeableAmountTile<T>> createState() => _SwipeableAmountTileState<T>();
}

class _SwipeableAmountTileState<T> extends State<SwipeableAmountTile<T>> {
  static const _viewportFraction = 0.82;
  // Base height at the Normal text-size setting — scaled by the current
  // text-scale factor at build time (see build() below), not used as-is.
  // A fixed pixel height overflowed at the Large setting: FittedBox already
  // shrinks the amount text to fit *width* (handles arbitrarily large
  // numbers, even billions), but nothing was growing the card's *height* to
  // match a bigger text-size setting, so the label + amount content simply
  // didn't fit inside a height that was sized for the Normal setting.
  static const _baseTileHeight = 190.0;

  late final PageController _controller;
  late int _page;

  int get _optionCount => widget.options.length;

  int _indexOf(T value) {
    final index = widget.options.indexWhere((o) => o.$1 == value);
    return index < 0 ? 0 : index;
  }

  /// Dart's `%` can return a negative result for a negative dividend — this
  /// normalizes it to always land in [0, optionCount), which is what makes
  /// PageView's real (unbounded) page index map onto a valid options index
  /// regardless of how far the user has swiped in either direction.
  int _wrap(int index) => ((index % _optionCount) + _optionCount) % _optionCount;

  @override
  void initState() {
    super.initState();
    _page = _indexOf(widget.selected);
    _controller = PageController(initialPage: _page, viewportFraction: _viewportFraction);
    WidgetsBinding.instance.addPostFrameCallback((_) => _playAffordanceHint());
  }

  /// Nudges the tile down slightly then settles back — demonstrates that it
  /// moves at all, once, rather than relying on the user to discover the
  /// gesture by accident. Uses a raw pixel offset (not animateToPage, which
  /// jumps a whole page) so it reads as a small "peek", not a real swipe.
  Future<void> _playAffordanceHint() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted || !_controller.hasClients) return;
    final start = _controller.offset;
    await _controller.animateTo(start + 22, duration: const Duration(milliseconds: 380), curve: Curves.easeOut);
    if (!mounted || !_controller.hasClients) return;
    await _controller.animateTo(start, duration: const Duration(milliseconds: 380), curve: Curves.easeIn);
  }

  @override
  void didUpdateWidget(covariant SwipeableAmountTile<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keeps the tile in sync if the period changes from somewhere other than
    // this widget's own swipe (there's no other call site today, but this
    // avoids a silent desync if one's ever added). Moves by the shortest
    // path rather than always forward.
    final targetIndex = _indexOf(widget.selected);
    if (_wrap(_page) == targetIndex || !_controller.hasClients) return;
    var delta = targetIndex - _wrap(_page);
    if (delta > _optionCount / 2) delta -= _optionCount;
    if (delta < -_optionCount / 2) delta += _optionCount;
    _controller.animateToPage(_page + delta, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scales the card's height by the same factor the text-size setting
    // applies to its text (0.9/1.0/1.15 — see app.dart's MediaQuery
    // override), so the label + amount always has enough room instead of
    // the card staying a fixed pixel height while its content grows taller.
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    return SizedBox(
      height: _baseTileHeight * textScale,
      child: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        onPageChanged: (page) {
          _page = page;
          widget.onChanged(widget.options[_wrap(page)].$1);
        },
        itemBuilder: (context, index) {
          final (value, label) = widget.options[_wrap(index)];
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              var distance = 0.0;
              if (_controller.hasClients && _controller.position.haveDimensions) {
                distance = ((_controller.page ?? _page.toDouble()) - index).abs().clamp(0.0, 1.0);
              } else if (index != _page) {
                distance = 1.0;
              }
              return Opacity(
                opacity: 1 - (distance * 0.4),
                child: Transform.scale(scale: 1 - (distance * 0.08), child: child),
              );
            },
            child: _HeroAmountCard(label: label, amountText: widget.amountFor(value)),
          );
        },
      ),
    );
  }
}

/// The "tile" itself — a bold gradient card built from the current accent
/// color, not a neutral surface. See the class doc above for why this
/// replaced an earlier low-contrast glass treatment.
class _HeroAmountCard extends StatelessWidget {
  final String label;
  final String amountText;

  const _HeroAmountCard({required this.label, required this.amountText});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          // Lighter than a plain primary->black(0.3) gradient (that version
          // read as "a little dark" to the user, though it's kept as a known-
          // good fallback — see git history/DESIGN_SYSTEM.md if reverting):
          // lightening the start stop toward white and easing off how far the
          // end stop darkens keeps the same directional depth with an overall
          // lighter card.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(colorScheme.primary, Colors.white, 0.15)!,
              Color.lerp(colorScheme.primary, Colors.black, 0.12)!,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          // A thin light-catching rim along the top/left edge — the kind of
          // subtle highlight a physical card or premium wallet-style UI
          // catches from a light source, not just a flat block of color.
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          boxShadow: [
            // Colored (not plain black) ambient shadow — it picks up the
            // card's own hue instead of looking like a generic drop shadow,
            // which is most of what reads as "premium" here.
            BoxShadow(color: colorScheme.primary.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onPrimary.withValues(alpha: 0.85))),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(amountText, style: textTheme.displayLarge?.copyWith(color: colorScheme.onPrimary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
