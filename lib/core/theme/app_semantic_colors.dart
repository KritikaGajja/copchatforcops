import 'package:flutter/material.dart';

class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.warning,
    required this.dangerGlow,
    required this.primaryDim,
    required this.textTertiary,
  });

  final Color success;
  final Color warning;
  final Color dangerGlow;
  final Color primaryDim;
  final Color textTertiary;

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? dangerGlow,
    Color? primaryDim,
    Color? textTertiary,
  }) -> AppSemanticColors(
     success: success ?? this.success,
     warning: warning ??this.warning,
     dangerGlow: dangerGlow ?? this.dangerGlow,
     primaryDim:primaryDim ?? this.primaryDim,
     textTertiary:textTertiary ?? this.textTertiary,
  );

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors> other,double t){
    if(other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success,t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      dangerGlow: Color.lerp(primaryDim,other.primaryDim,t)!,
      textTertiary: Color.lerp(textTertiary,other.textTertiary, t)!

    );
  }
}
