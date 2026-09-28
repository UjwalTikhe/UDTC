import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const TextStyle display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );
  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );
  static const TextStyle subtitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.45,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
  static const TextStyle codeHash = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    fontFamily: 'monospace',
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
  );
}