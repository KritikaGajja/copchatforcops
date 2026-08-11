import 'package:copchatforcops/core/theme/app_colors.dart';
import 'package:copchatforcops/core/theme/app_semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.background,
      surfaceContainer: AppColors.surface,
      surfaceContainerHighest: AppColors.surfaceRaised,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent, // AppBackground dikhega
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      extensions: const [
        AppSemanticColors(
          success: AppColors.success,
          warning: AppColors.warning,
          dangerGlow: AppColors.dangerGlow,
          primaryDim: AppColors.primaryDim,
          textTertiary: AppColors.textTertiary,
        ),
      ],
    );
  }
}
