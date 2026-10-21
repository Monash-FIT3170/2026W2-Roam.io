/*
 * Description:
 *   Shared "cartoon" building blocks layered on the Home palette: ink
 *   outlines, hard offset shadows, press-down buttons, and a Home-style
 *   page header. Party Mode uses the bold defaults; calmer screens such as
 *   Settings pass thinner outlines and smaller shadows.
 */

import 'package:flutter/material.dart';

import 'app_accessibility.dart';
import 'app_colours.dart';
import 'app_surfaces.dart';

/// Visual tokens for cartoon-styled surfaces.
class AppCartoon {
  static const double outlineWidth = 2.5;
  static const double shadowOffset = 4;

  /// Soft sage hairline drawn around surfaces, matching the app's borders.
  static Color outline(BuildContext context) {
    // High Contrast: a solid black (or white) outline, not a sage hairline.
    if (context.highContrast) return Theme.of(context).colorScheme.outline;
    return AppColors.sage.withValues(
      alpha: AppSurfaces.isDark(context) ? 0.4 : 0.28,
    );
  }

  /// Hard, unblurred drop shadow colour.
  static Color shadowColour(BuildContext context) {
    if (context.highContrast) return Theme.of(context).colorScheme.outline;
    return AppSurfaces.isDark(context)
        ? Colors.black.withValues(alpha: 0.7)
        : AppColors.ink;
  }

  static List<BoxShadow> hardShadow(
    BuildContext context, {
    double offset = shadowOffset,
  }) {
    return [
      BoxShadow(
        color: shadowColour(context),
        offset: Offset(0, offset),
        blurRadius: 0,
      ),
    ];
  }

  /// Outlined "sticker" card with a hard shadow.
  static BoxDecoration card(
    BuildContext context, {
    Color? color,
    double radius = 22,
    double offset = shadowOffset,
    double width = outlineWidth,
    bool soft = false,
    Color? outlineColor,
  }) {
    return BoxDecoration(
      color: color ?? AppSurfaces.card(context),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: outlineColor ?? outline(context), width: width),
      boxShadow: offset <= 0
          ? null
          : soft
          ? AppSurfaces.cardShadow(context)
          : hardShadow(context, offset: offset),
    );
  }

  /// Pill button style; pair with [CartoonPressable] for the shadow.
  static ButtonStyle button(
    BuildContext context, {
    required Color background,
    required Color foreground,
    double height = 52,
    double width = outlineWidth,
    Color? outlineColor,
  }) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? background.withValues(alpha: 0.5)
            : background,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? foreground.withValues(alpha: 0.6)
            : foreground,
      ),
      overlayColor: WidgetStatePropertyAll(foreground.withValues(alpha: 0.1)),
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: WidgetStatePropertyAll(Size(0, height)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 22),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      side: WidgetStatePropertyAll(
        BorderSide(color: outlineColor ?? outline(context), width: width),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// Dialog / sheet shape matching the cartoon cards.
  static ShapeBorder dialogShape(
    BuildContext context, {
    double width = outlineWidth,
  }) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: BorderSide(color: outline(context), width: width),
    );
  }

  /// Filled, ink-outlined text field decoration.
  static InputDecoration input(
    BuildContext context, {
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    double width = outlineWidth,
    Color? outlineColor,
    Color? fillColor,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
    final error = Theme.of(context).colorScheme.error;
    final edge = outlineColor ?? outline(context);
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: fillColor ?? AppSurfaces.softCard(context),
      border: border(edge),
      enabledBorder: border(edge),
      disabledBorder: border(edge.withValues(alpha: 0.4)),
      focusedBorder: border(AppColors.sage),
      errorBorder: border(error),
      focusedErrorBorder: border(error),
    );
  }
}

/// Wraps a button with a hard shadow that it "presses into" when tapped.
class CartoonPressable extends StatefulWidget {
  const CartoonPressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
    this.offset = AppCartoon.shadowOffset,
    this.soft = false,
    this.flat = false,
  });

  final Widget child;
  final bool enabled;
  final BorderRadius borderRadius;
  final double offset;

  /// Uses the app's blurred card shadow and a smaller press travel instead of
  /// the hard ink shadow.
  final bool soft;

  /// No shadow or press travel; for minimal screens such as Settings.
  final bool flat;

  @override
  State<CartoonPressable> createState() => _CartoonPressableState();
}

class _CartoonPressableState extends State<CartoonPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flat) return widget.child;
    final down = _pressed && widget.enabled;
    final offset = widget.soft
        ? 2.0
        : widget.enabled
        ? widget.offset
        : widget.offset / 2;
    final shadow = widget.soft
        ? AppSurfaces.cardShadow(context)
        : AppCartoon.hardShadow(context, offset: offset);
    return Listener(
      onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedContainer(
        duration: context.motionDuration(const Duration(milliseconds: 90)),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, down ? offset : 0, 0),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: down ? null : shadow,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Round, outlined icon button used in cartoon headers.
class CartoonIconButton extends StatelessWidget {
  const CartoonIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.background,
    this.foreground,
    this.outlineWidth = AppCartoon.outlineWidth,
    this.offset = 3,
    this.soft = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? background;
  final Color? foreground;
  final double outlineWidth;
  final double offset;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return CartoonPressable(
      enabled: onPressed != null,
      offset: offset,
      soft: soft,
      child: Material(
        color: background ?? AppSurfaces.softCard(context),
        shape: CircleBorder(
          side: BorderSide(
            color: AppCartoon.outline(context),
            width: outlineWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          color: foreground ?? AppSurfaces.textPrimary(context),
          constraints: const BoxConstraints.tightFor(width: 42, height: 42),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

/// Large page header matching the Home header, with a back button when the
/// route can pop and optional trailing actions.
class CartoonPageHeader extends StatelessWidget {
  const CartoonPageHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.showBrand = false,
    this.outlineWidth = AppCartoon.outlineWidth,
    this.shadowOffset = 3,
    this.soft = false,
    this.flat = false,
    this.outlineColor,
  });

  final String title;
  final List<Widget> actions;
  final bool showBrand;
  final double outlineWidth;
  final double shadowOffset;
  final bool soft;
  final bool flat;
  final Color? outlineColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Padding(
      padding: EdgeInsets.fromLTRB(canPop ? 16 : 20, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (canPop) ...[
            // A real BackButton keeps platform semantics and pageBack().
            CartoonPressable(
              offset: shadowOffset,
              soft: soft,
              flat: flat,
              child: Material(
                color: AppSurfaces.softCard(context),
                shape: CircleBorder(
                  side: BorderSide(
                    color: outlineColor ?? AppCartoon.outline(context),
                    width: outlineWidth,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox.square(
                  dimension: AppAccessibility.minTapTarget,
                  child: BackButton(
                    color: AppSurfaces.textPrimary(context),
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size.square(
                        AppAccessibility.minTapTarget,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: AppSurfaces.textPrimary(context),
                  fontSize: canPop ? 28 : 32,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.1,
                ),
              ),
            ),
          ),
          if (showBrand) ...[
            const SizedBox(width: 16),
            Text(
              'Roam.io',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.sage,
                fontSize: 17,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.35,
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/logos/roam_io_logo_transparent.png',
              height: 20,
              width: 20,
              color: AppColors.sage,
              colorBlendMode: BlendMode.srcIn,
            ),
          ],
          for (final action in actions) ...[const SizedBox(width: 10), action],
        ],
      ),
    );
  }
}
