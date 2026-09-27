import 'package:flutter/material.dart';

import '../../api/api_exception.dart';
import '../../theme.dart';

/// A bordered card. The prototype's look — 16px radius, hairline border, no
/// elevation — carried through, but reading its colours from the theme so it
/// works on the dark canvas.
class LedgerCard extends StatelessWidget {
  const LedgerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// A left-edge accent stripe, for rows that carry a status.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    final content = Padding(padding: padding, child: child);

    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          // The accent stripe is positioned in a Stack rather than laid out as a
          // stretched Row child. A Row with CrossAxisAlignment.stretch hands its
          // children an infinite height constraint when the card itself has no
          // bounded height — which is exactly the case inside a ListView — and
          // that is an assertion failure, not a cosmetic problem. A Stack sizes
          // to `content` and then fills the stripe to match it.
          child: accent == null
              ? content
              : ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      content,
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 4,
                        child: ColoredBox(color: accent!),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Section heading with an optional action on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// A small status pill. [tone] chooses the semantic colour so no caller
/// hard-codes one and breaks in dark mode.
enum PillTone { neutral, positive, negative, warning, accent }

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.tone = PillTone.neutral, this.icon});

  final String label;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    final foreground = switch (tone) {
      PillTone.neutral => colors.textSecondary,
      PillTone.positive => colors.positive,
      PillTone.negative => colors.negative,
      PillTone.warning => colors.warning,
      PillTone.accent => colors.accent,
    };
    // A 12% tint of the foreground keeps the pair at the same contrast ratio in
    // both themes without a second colour per tone.
    final background = tone == PillTone.neutral
        ? colors.cardRaised
        : foreground.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone == PillTone.neutral ? colors.border : Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: foreground), const SizedBox(width: 4)],
          // Flexible, because a pill is often placed in a narrow column — the
          // receivables tile on the dashboard is about 117px wide on a 390px
          // handset — and a label like "$3,080 overdue" overflows it. Truncating
          // is the right failure: the figure the pill sits under is the number
          // that matters, and the pill is a qualifier on it.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// What a list shows when it has nothing in it.
///
/// An empty state is not an error, and an accounting app's empty states are
/// usually good news — an empty review queue means the books are up to date.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: colors.accentSoft, shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: colors.accent),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

/// What a screen shows when a load failed.
///
/// The request id is on screen deliberately: every response carries one, and
/// support cannot trace a report without it. It is selectable so it can be
/// copied rather than transcribed from a photo of a phone.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry, this.compact = false});

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    final api = error is ApiException ? error as ApiException : null;
    final isOffline = api?.isNetworkError ?? false;
    final message = api?.displayMessage ?? 'Something went wrong. Try again.';

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: compact ? 28 : 40,
              color: colors.negative,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (api?.requestId != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                'Reference ${api!.requestId}',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A row of shimmer-free skeleton blocks. Plain grey placeholders rather than an
/// animated shimmer: a figure that appears to be moving reads as if it is still
/// changing, which is the wrong impression for a bank balance.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({super.key, this.width, this.height = 16, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.c.border,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A labelled value, the shape most detail rows take.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasise
                  ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
                  : theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          // A label and a value that are both long — "PAYG withholding" beside a
          // six-figure amount — need the value to be able to wrap rather than
          // run off the card.
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: (emphasise ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge)
                  ?.copyWith(color: valueColor, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows an error to the user in the visible layer, never behind a modal.
void showErrorToast(BuildContext context, Object error) {
  final api = error is ApiException ? error : null;
  final message = api?.displayMessage ?? 'Something went wrong. Try again.';
  final reference = api?.requestId;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(reference == null ? message : '$message\nReference $reference'),
        duration: const Duration(seconds: 6),
        backgroundColor: context.c.negative,
      ),
    );
}

void showSuccessToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 4)));
}
