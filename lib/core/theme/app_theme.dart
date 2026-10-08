import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'glass_tokens.dart';

/// App-wide theming for the frosted-glass design language.
///
/// Surfaces are deliberately transparent: the [AuroraBackground] mounted in
/// `MaterialApp.builder` provides the colour, and every pane above it blurs
/// what it covers. That means scaffolds, app bars and dialogs must never paint
/// an opaque fill, or the effect collapses.
class AppTheme {
  const AppTheme._();

  static const _fontFamily = 'itfQomra';

  // Built once per process EACH, and there are four rather than two because
  // the glass-free variants are a different token set rather than a runtime
  // flag read at paint time. Nothing in any of them depends on state that
  // changes while the app runs, and `_build` runs ColorScheme.fromSeed plus
  // ~20 sub-themes — work the shell was once repeating on every rebuild that
  // watched settings.
  static final ThemeData _light = _build(Brightness.light);
  static final ThemeData _dark = _build(Brightness.dark);
  static final ThemeData _lightSolid = _build(Brightness.light, solid: true);
  static final ThemeData _darkSolid = _build(Brightness.dark, solid: true);

  /// [solid] takes the glass out: opaque panes, no blur, heavier hairlines.
  /// One switch for two complaints — sunlight and cheap handsets — that turn
  /// out to have one fix. See [GlassTokens.lightSolid].
  static ThemeData light({bool solid = false}) => solid ? _lightSolid : _light;
  static ThemeData dark({bool solid = false}) => solid ? _darkSolid : _dark;

  /// Mixes two palette entries. Used only to pull a brand colour towards
  /// [AppColors.black] or [AppColors.white] — never to invent a hue.
  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  static ThemeData _build(Brightness brightness, {bool solid = false}) {
    final isDark = brightness == Brightness.dark;

    // The deep greens carry enough weight on paper to be the primary; on a
    // near-black field they close up, so dark mode steps to the light green.
    final primary = isDark ? AppColors.lightGreen : AppColors.darkGreen;

    // The reds are all deep by design — legible on paper, muddy on black — so
    // dark mode lifts the error tone towards white rather than swapping hue.
    final error = isDark
        ? _mix(AppColors.lightRed, AppColors.white, 0.4)
        : AppColors.lightRed;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.mediumGreen,
          brightness: brightness,
          primary: primary,
          secondary: isDark ? AppColors.mediumGold : AppColors.darkGold,
          tertiary: isDark ? AppColors.darkGold : AppColors.mediumRed,
          error: error,
        ).copyWith(
          // The colour of a SURFACE, which on paper is the pane and not the
          // desk it stands on. Anything reading this is filling something a
          // pane already contains — the separator between two segments of a
          // stacked bar, say — and wants to match the card under it.
          surface: isDark ? AppColors.nightMid : AppColors.white,
          surfaceTint: Colors.transparent,
          // Text/icon tones are tuned by hand: auto-generated onSurface values
          // wash out over a translucent, colour-shifting backdrop.
          onPrimary: isDark ? AppColors.ink : AppColors.white,
          onSecondary: AppColors.ink,
          onTertiary: isDark ? AppColors.ink : AppColors.white,
          onError: isDark ? AppColors.ink : AppColors.white,
          // Pinned rather than left to the tonal palette: fromSeed derives
          // container roles by shifting tone AND chroma, which drifts off the
          // brand greens.
          primaryContainer: isDark
              ? _mix(AppColors.black, AppColors.darkGreen, 0.55)
              : _mix(AppColors.white, AppColors.lightGreen, 0.28),
          onPrimaryContainer: isDark ? AppColors.inkInverse : AppColors.ink,
          surfaceContainerHigh: isDark
              ? _mix(AppColors.nightMid, AppColors.white, 0.07)
              : _mix(AppColors.paperMid, AppColors.black, 0.05),
          surfaceContainerHighest: isDark
              ? _mix(AppColors.nightMid, AppColors.white, 0.12)
              : _mix(AppColors.paperMid, AppColors.black, 0.09),
          onSurface: isDark ? AppColors.inkInverse : AppColors.ink,
          onSurfaceVariant: isDark ? AppColors.hint : AppColors.hintStrong,
          // Both are drawn on a pane, which on paper is white — so the light
          // steps are measured from white and had to grow: at 0.14 a divider
          // ruled across a card was a shade off the card itself, and callers
          // that fade it further (see [InfoSection]) were ruling nothing.
          //
          // Neutral rather than green, for the reason [GlassTokens.light]
          // gives at length: these rule across panes that may be washed red or
          // gold, and a line with a hue of its own argues with the wash. The
          // night steps keep their green because they are drawn on a backdrop
          // that IS green, and because nothing on night was ever wrong.
          outline: isDark
              ? _mix(AppColors.black, AppColors.lightGreen, 0.3)
              : _mix(AppColors.white, AppColors.black, 0.25),
          outlineVariant: isDark
              ? _mix(AppColors.black, AppColors.lightGreen, 0.15)
              : _mix(AppColors.white, AppColors.black, 0.16),
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: _fontFamily,
      // Transparent: the aurora behind the app is the background.
      scaffoldBackgroundColor: Colors.transparent,
      // NOT transparent, and this is the one place the rule has to stop.
      // `DropdownButtonFormField` paints its open menu with `canvasColor`, so a
      // transparent one left every dropdown in the app see-through: the list of
      // job titles read over whatever the page behind it happened to be. A menu
      // is a thing you read a list from, and it has to be solid.
      //
      // Safe to make opaque because nothing else here reaches it — no Drawer,
      // no Stepper, no `MaterialType.canvas` — and the aurora shows through
      // `scaffoldBackgroundColor`, which is still transparent above.
      canvasColor: isDark ? AppColors.nightTop : AppColors.white,
      // The sparkle is a FRAGMENT SHADER, and the web engine loads it by
      // fetching `ink_sparkle.frag` and decoding it as UTF-8 — which throws on
      // the first byte that is not text, before anything is drawn. So the web
      // gets the classic ripple, which needs no shader and looks near enough,
      // and every other platform keeps the sparkle it was chosen for.
      splashFactory: kIsWeb
          ? InkRipple.splashFactory
          : InkSparkle.splashFactory,
    );

    final glass = solid
        ? (isDark ? GlassTokens.darkSolid : GlassTokens.lightSolid)
        : (isDark ? GlassTokens.dark : GlassTokens.light);

    final textTheme = base.textTheme
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            height: 1.2,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            height: 1.25,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
          bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.4),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        );

    final borderRadius = BorderRadius.circular(AppRadius.sm);

    return base.copyWith(
      extensions: [glass],
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 19),
      ),
      // Kept in sync with GlassCard for the few places Material still builds a
      // Card for us (dropdown menus, date pickers).
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark
            ? AppColors.nightMid.withValues(alpha: 0.90)
            : AppColors.white.withValues(alpha: 0.95),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: glass.stroke),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // A field is a WELL, and a well is a step away from the surface it is
        // cut into — up on night, down on paper. The light value used to be
        // white over a card that is itself white, which is how every form in
        // the app came to be a set of labels with borders drawn round them.
        fillColor: isDark
            ? AppColors.white.withValues(alpha: 0.06)
            : AppColors.black.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg + 2,
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: glass.stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: glass.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.35),
          elevation: 0,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          foregroundColor: scheme.onSurface,
          backgroundColor: isDark
              ? AppColors.white.withValues(alpha: 0.05)
              : AppColors.black.withValues(alpha: 0.03),
          side: BorderSide(color: glass.strokeStrong),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          highlightColor: scheme.primary.withValues(alpha: 0.12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      // A chip that is on must not look like a chip that is off. Left to the
      // defaults the two differed by a tint barely visible over the glass, so
      // the selected state is stated three times over — filled, outlined in the
      // accent, and its label in that accent at a heavier weight — and the
      // unselected one keeps the plain hairline it always had.
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? AppColors.white.withValues(alpha: 0.06)
            : AppColors.black.withValues(alpha: 0.045),
        selectedColor: scheme.primary.withValues(alpha: isDark ? 0.32 : 0.20),
        secondarySelectedColor: scheme.primary.withValues(
          alpha: isDark ? 0.32 : 0.20,
        ),
        checkmarkColor: scheme.primary,
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BorderSide(color: scheme.primary, width: 1.4)
              : BorderSide(color: glass.stroke),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      // The same promise the drawn indicator makes, kept by the Material
      // checkbox where one is used: empty is hollow, chosen is filled.
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(scheme.onPrimary),
        side: BorderSide(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
          width: 1.6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: scheme.primary, width: 2.5),
          insets: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        ),
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark
            ? AppColors.nightTop.withValues(alpha: 0.94)
            : AppColors.white.withValues(alpha: 0.97),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: glass.stroke),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark
            ? AppColors.nightTop.withValues(alpha: 0.94)
            : AppColors.white.withValues(alpha: 0.97),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark
            ? AppColors.nightTop.withValues(alpha: 0.94)
            : AppColors.white.withValues(alpha: 0.97),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: glass.stroke),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // Always the dark treatment: a snack bar reads as an overlay, not as
        // part of the page it covers.
        backgroundColor: AppColors.nightMid.withValues(alpha: 0.95),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.inkInverse,
        ),
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: AppColors.white.withValues(alpha: 0.12)),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll(glass.stroke),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        iconColor: scheme.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: 0.15),
        circularTrackColor: scheme.primary.withValues(alpha: 0.15),
      ),
    );
  }
}
