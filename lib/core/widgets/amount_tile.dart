import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// The big total-spend number on Home and Analytics, in a proper rectangular
/// card rather than bare text floating on the background. The amount is
/// wrapped in a FittedBox(fit: scaleDown) so it scales to whatever the
/// number actually needs: a huge total (crores, or hypothetically a
/// billionaire's transaction history) shrinks to fit the tile's width
/// instead of overflowing or wrapping, while a small one (₹5, ₹10) is never
/// artificially enlarged or shrunk — it just renders at the intended size.
class AmountTile extends StatelessWidget {
  final Widget header;
  final String amountText;

  const AmountTile({super.key, required this.header, required this.amountText});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(amountText, style: textTheme.displayLarge),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
