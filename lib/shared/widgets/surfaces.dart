import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/brand.dart';

/// The standard content card.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: Card(
        color: color,
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// Section title with an optional trailing action ("See all").
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(20, 28, 12, 12),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: context.text.titleMedium),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: context.text.bodySmall),
                ],
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Small uppercase label above numbers.
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: context.text.labelSmall!
          .copyWith(color: color ?? context.colors.textMuted),
    );
  }
}

enum TagTone { neutral, primary, accent, warning, muted }

/// Compact pill for statuses and hints.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.tone = TagTone.neutral, this.icon});

  final String label;
  final TagTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (tone) {
      TagTone.neutral => (c.chartTrack, c.textSecondary),
      TagTone.primary => (c.primarySoft, c.onPrimarySoft),
      TagTone.accent => (c.accentSoft, c.onAccentSoft),
      TagTone.warning => (c.warning.withValues(alpha: 0.16), c.warning),
      TagTone.muted => (Colors.transparent, c.textMuted),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: icon == null ? 8 : 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: tone == TagTone.muted ? Border.all(color: c.hairline) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: context.text.labelSmall!
                  .copyWith(color: fg, letterSpacing: 0.2, fontSize: 11)),
        ],
      ),
    );
  }
}

/// Renders an amount with de-emphasised cents: **€183**.42
class AmountText extends StatelessWidget {
  const AmountText(
    this.formatted, {
    super.key,
    required this.style,
    this.centsOpacity = 0.55,
    this.centsScale = 0.62,
    this.semanticsLabel,
  });

  /// Already formatted amount, e.g. "€1,234.56".
  final String formatted;
  final TextStyle style;
  final double centsOpacity;
  final double centsScale;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final dot = formatted.lastIndexOf('.');
    final hasCents = dot > 0 && formatted.length - dot == 3;
    final main = hasCents ? formatted.substring(0, dot) : formatted;
    final cents = hasCents ? formatted.substring(dot) : '';
    final base = style.figures;
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: main, style: base),
        if (cents.isNotEmpty)
          TextSpan(
            text: cents,
            style: base.copyWith(
              fontSize: (base.fontSize ?? 14) * centsScale,
              color: base.color?.withValues(alpha: centsOpacity),
              letterSpacing: 0,
            ),
          ),
      ]),
      semanticsLabel: semanticsLabel ?? formatted,
      maxLines: 1,
      softWrap: false,
    );
  }
}

/// Friendly empty state with the brand mark tone.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 32, color: c.onPrimarySoft),
          ),
          const SizedBox(height: 20),
          Text(title,
              textAlign: TextAlign.center, style: context.text.titleLarge),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium!.copyWith(color: c.textSecondary),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.accentSoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.cloud_off_rounded, size: 32, color: c.onAccentSoft),
            ),
            const SizedBox(height: 20),
            Text("Couldn't load your data",
                style: context.text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                style: context.text.bodyMedium!.copyWith(color: c.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A gently pulsing placeholder block for loading states.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = Brand.radiusL,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.colors.chartTrack;
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Generic loading layout used while the store is loading.
class LoadingList extends StatelessWidget {
  const LoadingList({super.key, this.hero = true});

  final bool hero;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          if (hero) ...[
            const SkeletonBox(height: 210, radius: Brand.radiusXL),
            const SizedBox(height: 16),
            const Row(children: [
              Expanded(child: SkeletonBox(height: 92)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 92)),
            ]),
            const SizedBox(height: 28),
          ],
          for (var i = 0; i < 5; i++) ...[
            const SkeletonBox(height: 68, radius: Brand.radiusM),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
