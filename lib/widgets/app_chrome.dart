import 'dart:ui';

import 'package:flutter/foundation.dart';
import '../l10n/app_strings.dart';
import '../l10n/localized_material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/chessnut_theme.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = ChessnutTheme.tokensOf(context);
    final compactLandscape = isCompactLandscapeDevice(context);
    final effectsEnabled =
        tokens.visualEffectsEnabled && !MediaQuery.disableAnimationsOf(context);
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (effectsEnabled &&
              !compactLandscape &&
              tokens.visualTheme == ChessnutVisualTheme.classic) ...[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      tokens.backgroundGlowPrimary,
                      Colors.transparent,
                      tokens.backgroundGlowSecondary,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 18,
              top: 82,
              child: _BoardWatermark(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.035),
              ),
            ),
          ],
          if (effectsEnabled &&
              !compactLandscape &&
              tokens.showAmbientGlow) ...[
            Positioned(
              right: -116,
              top: -112,
              child: _Glow(size: 220, color: tokens.backgroundGlowPrimary),
            ),
            Positioned(
              left: -108,
              top: 220,
              child: _Glow(size: 190, color: tokens.backgroundGlowSecondary),
            ),
          ],
          SafeArea(
            left: false,
            right: false,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _BoardWatermark extends StatelessWidget {
  const _BoardWatermark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 188,
        height: 188,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 64,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
          ),
          itemBuilder: (context, index) {
            final file = index % 8;
            final rank = index ~/ 8;
            final darkSquare = (file + rank).isOdd;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: darkSquare ? color : Colors.transparent,
              ),
            );
          },
        ),
      ),
    );
  }
}

class ResponsiveSpec {
  const ResponsiveSpec(
    this.width, {
    this.height = double.infinity,
    this.compactLandscapeOverride = false,
    this.disableCompactLandscape = false,
  });

  final double width;
  final double height;
  final bool compactLandscapeOverride;
  final bool disableCompactLandscape;

  bool get compact => width < 700;
  bool get medium => width >= 700 && width < 1100;
  bool get expanded => width >= 1100;
  bool get canSplit => width >= 840;
  bool get compactLandscape =>
      compactLandscapeOverride ||
      (!disableCompactLandscape &&
          usesCompactLandscapeLayout(Size(width, height)));

  double get gutter {
    if (compactLandscape) return 8;
    if (expanded) return 20;
    if (medium) return 16;
    return 12;
  }

  double get horizontalPadding {
    if (compactLandscape) return 10;
    if (expanded) return 28;
    if (medium) return 22;
    return 14;
  }

  double get topPadding => compactLandscape ? 8 : (compact ? 18 : 24);
  double get bottomPadding => compactLandscape ? 8 : (compact ? 18 : 28);

  double get contentHeight {
    if (!height.isFinite) return double.infinity;
    return (height - topPadding - bottomPadding).clamp(0, height).toDouble();
  }

  double heightAfterHeader({double min = 0}) {
    if (!height.isFinite) return min;
    final headerAllowance = compactLandscape ? 58 : 78;
    return (contentHeight - headerAllowance).clamp(min, height).toDouble();
  }

  double get maxContentWidth {
    if (expanded) return 1260;
    return double.infinity;
  }

  int columnsFor({
    required double minTileWidth,
    int min = 1,
    int max = 4,
  }) {
    final usable = width - horizontalPadding * 2;
    final columns = ((usable + gutter) / (minTileWidth + gutter)).floor();
    return columns.clamp(min, max).toInt();
  }
}

class ResponsivePage extends StatefulWidget {
  const ResponsivePage({
    required this.children,
    this.scrollController,
    this.compactLandscapeOverride = false,
    this.disableCompactLandscape = false,
    this.preserveLayoutWhenKeyboardVisible = false,
    super.key,
  });

  final List<Widget> Function(BuildContext context, ResponsiveSpec spec)
      children;
  final ScrollController? scrollController;
  final bool compactLandscapeOverride;
  final bool disableCompactLandscape;
  final bool preserveLayoutWhenKeyboardVisible;

  @override
  State<ResponsivePage> createState() => _ResponsivePageState();
}

class _ResponsivePageState extends State<ResponsivePage> {
  double? _keyboardHiddenHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        final preserveLayout = widget.preserveLayoutWhenKeyboardVisible &&
            (keyboardInset > 0 || hasFocusedTextInput());
        if (!preserveLayout) {
          _keyboardHiddenHeight = height;
        }
        final responsiveHeight =
            preserveLayout ? (_keyboardHiddenHeight ?? height) : height;
        final spec = ResponsiveSpec(
          width,
          height: responsiveHeight,
          compactLandscapeOverride: widget.compactLandscapeOverride,
          disableCompactLandscape: widget.disableCompactLandscape,
        );
        final list = ListView(
          controller: widget.scrollController,
          physics: spec.compactLandscape
              ? const ClampingScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            spec.horizontalPadding,
            spec.topPadding,
            spec.horizontalPadding,
            spec.bottomPadding +
                (widget.preserveLayoutWhenKeyboardVisible ? keyboardInset : 0),
          ),
          children: widget.children(context, spec),
        );

        final useFullWidth = !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.macOS) &&
            spec.expanded;
        if (useFullWidth || !spec.maxContentWidth.isFinite) return list;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: spec.maxContentWidth),
            child: list,
          ),
        );
      },
    );
  }
}

class ResponsiveSplit extends StatelessWidget {
  const ResponsiveSplit({
    required this.leading,
    required this.trailing,
    this.breakpoint = 840,
    this.leadingFlex = 6,
    this.trailingFlex = 5,
    this.spacing = 16,
    this.trailingFirstOnCompact = false,
    super.key,
  });

  final Widget leading;
  final Widget trailing;
  final double breakpoint;
  final int leadingFlex;
  final int trailingFlex;
  final double spacing;
  final bool trailingFirstOnCompact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        if (width >= breakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: leadingFlex, child: leading),
              SizedBox(width: spacing),
              Expanded(flex: trailingFlex, child: trailing),
            ],
          );
        }

        final items = trailingFirstOnCompact
            ? [trailing, SizedBox(height: spacing), leading]
            : [leading, SizedBox(height: spacing), trailing];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items,
        );
      },
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    required this.children,
    this.minTileWidth = 154,
    this.maxColumns = 4,
    this.spacing = 10,
    this.childAspectRatio = 1.35,
    super.key,
  });

  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;
  final double spacing;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final count = ((width + spacing) / (minTileWidth + spacing))
            .floor()
            .clamp(
              1,
              maxColumns,
            )
            .toInt();
        return GridView.count(
          crossAxisCount: count,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: childAspectRatio,
          children: children,
        );
      },
    );
  }
}

class SectionColumn extends StatelessWidget {
  const SectionColumn({
    required this.children,
    this.spacing = 12,
    super.key,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          children[i],
        ],
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 14,
    this.tint,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ChessnutTheme.tokensOf(context);
    final compactLandscape = isCompactLandscapeDevice(context);
    final resolvedRadius =
        borderRadius == 14 ? tokens.panelRadius : borderRadius;
    final radius = BorderRadius.circular(resolvedRadius);
    final fill = tint ?? tokens.panelFill;
    final border = tokens.panelBorder;
    final effectivePadding =
        compactLandscape ? _compactPadding(padding) : padding;
    final effectsEnabled =
        tokens.visualEffectsEnabled && !MediaQuery.disableAnimationsOf(context);
    final blurEnabled = effectsEnabled && !compactLandscape;

    Widget content = ConstrainedBox(
      constraints:
          BoxConstraints(minHeight: onTap == null ? 0 : tokens.touchTarget),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          enabled: blurEnabled,
          child: _PanelContainer(
            padding: effectivePadding,
            radius: radius,
            fill: fill,
            border: border,
            shadow: blurEnabled ? tokens.panelShadow : Colors.transparent,
            blurRadius: blurEnabled
                ? (tokens.visualTheme == ChessnutVisualTheme.classic ? 10 : 18)
                : 0,
            shadowOffset: blurEnabled
                ? (tokens.visualTheme == ChessnutVisualTheme.classic ? 5 : 10)
                : 0,
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      content = Semantics(
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: content,
          ),
        ),
      );
    }

    return content;
  }
}

class _PanelContainer extends StatelessWidget {
  const _PanelContainer({
    required this.padding,
    required this.radius,
    required this.fill,
    required this.border,
    required this.shadow,
    required this.blurRadius,
    required this.shadowOffset,
    required this.child,
  });

  final EdgeInsetsGeometry padding;
  final BorderRadius radius;
  final Color fill;
  final Color border;
  final Color shadow;
  final double blurRadius;
  final double shadowOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: isCompactLandscapeDevice(context) ||
              !ChessnutTheme.tokensOf(context).visualEffectsEnabled ||
              MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: fill,
        border: Border.all(color: border),
        boxShadow: [
          if (blurRadius > 0)
            BoxShadow(
              color: shadow,
              blurRadius: blurRadius,
              offset: Offset(0, shadowOffset),
            ),
        ],
      ),
      child: child,
    );
  }
}

EdgeInsetsGeometry _compactPadding(EdgeInsetsGeometry padding) {
  if (padding is EdgeInsets) {
    return EdgeInsets.fromLTRB(
      padding.left.clamp(0, 10).toDouble(),
      padding.top.clamp(0, 8).toDouble(),
      padding.right.clamp(0, 10).toDouble(),
      padding.bottom.clamp(0, 8).toDouble(),
    );
  }
  if (padding is EdgeInsetsDirectional) {
    return EdgeInsetsDirectional.fromSTEB(
      padding.start.clamp(0, 10).toDouble(),
      padding.top.clamp(0, 8).toDouble(),
      padding.end.clamp(0, 10).toDouble(),
      padding.bottom.clamp(0, 8).toDouble(),
    );
  }
  return padding;
}

bool isCompactLandscapeDevice(BuildContext context) {
  return usesCompactLandscapeLayout(MediaQuery.sizeOf(context));
}

bool usesCompactLandscapeLayout(Size size) {
  return size.width >= 900 && size.height <= 560;
}

bool hasFocusedTextInput() {
  final focusContext = FocusManager.instance.primaryFocus?.context;
  if (focusContext == null) return false;
  return focusContext.widget is EditableText ||
      focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.titleKey,
    this.titleMaxLines,
    this.titleOverflow,
    this.scaleTitleToFit = false,
    this.compactTrailingFraction = 0.34,
    this.trailingMaxWidth,
    this.trailingPinnedToRight = true,
    this.reservePinnedTrailingWidth = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Key? titleKey;
  final int? titleMaxLines;
  final TextOverflow? titleOverflow;
  final bool scaleTitleToFit;
  final double compactTrailingFraction;
  final double? trailingMaxWidth;
  final bool trailingPinnedToRight;
  final bool reservePinnedTrailingWidth;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.maybeOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final resolvedTrailingMaxWidth = (trailingMaxWidth ??
                (constraints.maxWidth *
                        (compact ? compactTrailingFraction : 0.44))
                    .clamp(0.0, 220.0))
            .clamp(0.0, constraints.maxWidth);
        final pinnedTrailing = trailingPinnedToRight && trailing != null;
        final titleText = Text(
          key: titleKey,
          strings?.t(title) ?? title,
          maxLines: scaleTitleToFit ? 1 : titleMaxLines ?? (compact ? 2 : 1),
          softWrap: scaleTitleToFit ? false : null,
          overflow: scaleTitleToFit
              ? TextOverflow.visible
              : titleOverflow ??
                  (compact ? TextOverflow.visible : TextOverflow.ellipsis),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
        );
        final titleBlock = Row(
          children: [
            leading ?? const LogoButton(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subtitle != null)
                    Text(
                      (strings?.t(subtitle!) ?? subtitle!).toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  if (scaleTitleToFit)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: titleText,
                    )
                  else
                    titleText,
                ],
              ),
            ),
            if (!pinnedTrailing && trailing != null) ...[
              const SizedBox(width: 8),
              Flexible(
                fit: FlexFit.loose,
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: resolvedTrailingMaxWidth),
                  child: Align(
                    alignment: Alignment.centerRight,
                    widthFactor: 1,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: trailing!,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
        if (!pinnedTrailing) return titleBlock;

        final trailingSlot = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: resolvedTrailingMaxWidth),
          child: Align(
            alignment: Alignment.centerRight,
            widthFactor: 1,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: trailing!,
            ),
          ),
        );

        if (!reservePinnedTrailingWidth) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: ChessnutTheme.tokensOf(context).touchTarget,
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                titleBlock,
                Positioned(
                  right: 0,
                  child: trailingSlot,
                ),
              ],
            ),
          );
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: ChessnutTheme.tokensOf(context).touchTarget,
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  right: resolvedTrailingMaxWidth + 8,
                ),
                child: titleBlock,
              ),
              Positioned(
                right: 0,
                child: trailingSlot,
              ),
            ],
          ),
        );
      },
    );
  }
}

class LogoButton extends StatelessWidget {
  const LogoButton({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = ChessnutTheme.tokensOf(context);
    return Container(
      width: tokens.visualTheme == ChessnutVisualTheme.classic ? 46 : 42,
      height: tokens.visualTheme == ChessnutVisualTheme.classic ? 46 : 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(tokens.controlRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: SvgPicture.asset('assets/images/chessnut_logo.svg'),
    );
  }
}

class ActionTile extends StatelessWidget {
  const ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.selected = false,
    this.selectedBackground = true,
    this.badge = false,
    this.onTap,
    this.compactLandscapeProminent = false,
    this.compactLandscapeOverride = false,
    this.disableCompactLandscape = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool selectedBackground;
  final bool badge;
  final VoidCallback? onTap;
  final bool compactLandscapeProminent;
  final bool compactLandscapeOverride;
  final bool disableCompactLandscape;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = ChessnutTheme.tokensOf(context);
    final compactLandscape = compactLandscapeOverride ||
        (!disableCompactLandscape && isCompactLandscapeDevice(context));
    final tint = selected && selectedBackground
        ? scheme.primary.withValues(alpha: 0.07)
        : null;
    final compactMinHeight = compactLandscapeProminent ? 74.0 : 48.0;
    final compactPadding = compactLandscapeProminent ? 9.0 : 7.0;
    return GlassPanel(
      onTap: onTap,
      padding: EdgeInsets.zero,
      tint: tint,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: compactLandscape
              ? compactMinHeight
              : (tokens.visualTheme == ChessnutVisualTheme.classic ? 86 : 78),
        ),
        child: Padding(
          padding: EdgeInsets.all(
            compactLandscape ? compactPadding : 10,
          ),
          child: compactLandscape
              ? Row(
                  children: [
                    _ActionIcon(
                      icon: icon,
                      selected: selected,
                      scheme: scheme,
                      tokens: tokens,
                      compact: true,
                      prominent: compactLandscapeProminent,
                      badge: badge,
                    ),
                    SizedBox(width: compactLandscapeProminent ? 10 : 8),
                    Expanded(
                      child: compactLandscapeProminent
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.visible,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    height: 1.08,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.visible,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            )
                          : Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.visible,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                height: 1.05,
                              ),
                            ),
                    ),
                    if (compactLandscapeProminent) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: selected ? scheme.primary : scheme.secondary,
                      ),
                    ],
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ActionIcon(
                      icon: icon,
                      selected: selected,
                      scheme: scheme,
                      tokens: tokens,
                      badge: badge,
                    ),
                    const Spacer(),
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.visible,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withValues(alpha: 0.68)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.selected,
    required this.scheme,
    required this.tokens,
    this.compact = false,
    this.prominent = false,
    this.badge = false,
  });

  final IconData icon;
  final bool selected;
  final ColorScheme scheme;
  final ChessnutThemeTokens tokens;
  final bool compact;
  final bool prominent;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final dimension = compact ? (prominent ? 40.0 : 34.0) : 36.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: isCompactLandscapeDevice(context) ||
                  !ChessnutTheme.tokensOf(context).visualEffectsEnabled ||
                  MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          width: dimension,
          height: dimension,
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.12)
                : scheme.secondary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(tokens.controlRadius),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.24)
                  : Colors.transparent,
            ),
          ),
          child: Icon(
            icon,
            size: compact ? (prominent ? 24 : 23) : 24,
            color: selected ? scheme.primary : scheme.secondary,
          ),
        ),
        if (badge)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: tokens.success,
                shape: BoxShape.circle,
                border:
                    Border.all(color: Theme.of(context).cardColor, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    this.icon,
    this.onPressed,
    this.labelMaxLines = 2,
    this.labelSoftWrap = true,
    this.labelOverflow = TextOverflow.visible,
    this.scaleLabel = false,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final int labelMaxLines;
  final bool labelSoftWrap;
  final TextOverflow labelOverflow;
  final bool scaleLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = ChessnutTheme.tokensOf(context);
    final compactLandscape = isCompactLandscapeDevice(context);
    final labelWidget = Text(
      AppStrings.maybeOf(context)?.t(label) ?? label,
      maxLines: labelMaxLines,
      softWrap: labelSoftWrap,
      overflow: labelOverflow,
      textAlign: TextAlign.center,
    );
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_forward_rounded),
      label: scaleLabel
          ? FittedBox(fit: BoxFit.scaleDown, child: labelWidget)
          : labelWidget,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        minimumSize: Size.fromHeight(
          compactLandscape ? (tokens.touchTarget + 10) : tokens.touchTarget,
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
        ),
        textStyle: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: compactLandscape ? 16 : 15,
        ),
      ),
    );
  }
}

class AppDialogShell extends StatelessWidget {
  const AppDialogShell({
    required this.icon,
    required this.title,
    this.subtitle,
    this.child,
    this.actions = const [],
    this.compactLandscapeOverride = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? child;
  final List<Widget> actions;
  final bool compactLandscapeOverride;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final scheme = Theme.of(context).colorScheme;
    final compactLandscape =
        compactLandscapeOverride || isCompactLandscapeDevice(context);
    final strings = AppStrings.maybeOf(context);
    return Dialog(
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: compactLandscape ? 760 : 430,
          maxHeight:
              (size.height - viewPadding.top - viewPadding.bottom - 48) * 0.92,
        ),
        child: GlassPanel(
          borderRadius: 18,
          padding: const EdgeInsets.all(14),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: scheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings?.t(title) ?? title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              strings?.t(subtitle!) ?? subtitle!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (child != null) ...[
                  const SizedBox(height: 12),
                  child!,
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stackActions =
                          constraints.maxWidth < 360 || actions.length > 2;
                      if (stackActions) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < actions.length; i++) ...[
                              SizedBox(
                                width: double.infinity,
                                child: _dialogActionButton(actions[i]),
                              ),
                              if (i != actions.length - 1)
                                const SizedBox(height: 10),
                            ],
                          ],
                        );
                      }
                      return Row(
                        children: [
                          for (var i = 0; i < actions.length; i++) ...[
                            _dialogActionRowChild(actions[i]),
                            if (i != actions.length - 1)
                              const SizedBox(width: 10),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _dialogActionButton(Widget action) {
  if (action is Flexible) return action.child;
  return action;
}

Widget _dialogActionRowChild(Widget action) {
  if (action is Flexible) return action;
  return Expanded(child: action);
}

class ResponsiveBoardFrame extends StatelessWidget {
  const ResponsiveBoardFrame({
    required this.builder,
    this.maxSize = 326,
    this.shortSideMaxSize,
    this.extraWidth = 0,
    this.padding = const EdgeInsets.all(10),
    this.borderRadius = 16,
    this.tint,
    super.key,
  });

  final Widget Function(double size) builder;
  final double maxSize;
  final double? shortSideMaxSize;
  final double extraWidth;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = padding.horizontal;
        final verticalPadding = padding.vertical;
        final widthAvailable = constraints.maxWidth.isFinite
            ? constraints.maxWidth - horizontalPadding - extraWidth - 2
            : maxSize;
        final heightAvailable = constraints.maxHeight.isFinite
            ? constraints.maxHeight - verticalPadding
            : widthAvailable;
        final limit = shortSideMaxSize ?? maxSize;
        final shortSide =
            widthAvailable < heightAvailable ? widthAvailable : heightAvailable;
        final boardSize = shortSide.clamp(180.0, limit).toDouble();
        return Center(
          child: GlassPanel(
            padding: padding,
            borderRadius: borderRadius,
            tint: tint,
            child: SizedBox(
              width: boardSize + extraWidth,
              height: boardSize,
              child: builder(boardSize),
            ),
          ),
        );
      },
    );
  }
}

class BoardEditorBoardTools extends StatelessWidget {
  const BoardEditorBoardTools({
    required this.statusKey,
    required this.connected,
    required this.onStatusTap,
    super.key,
  });

  final Key statusKey;
  final bool connected;
  final VoidCallback onStatusTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BoardEditorToolIconButton(
          key: statusKey,
          icon: connected ? Icons.sensors_rounded : Icons.sensors_off_rounded,
          color: connected ? scheme.primary : scheme.secondary,
          tooltip: connected ? 'Physical board sync' : 'Board sync status',
          onTap: onStatusTap,
        ),
      ],
    );
  }
}

class _BoardEditorToolIconButton extends StatelessWidget {
  const _BoardEditorToolIconButton({
    super.key,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.icon,
  });

  final IconData? icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: onTap == null ? 0.06 : 0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: Center(
              child: Icon(icon, color: color, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
