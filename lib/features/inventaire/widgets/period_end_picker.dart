import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Lets the admin pick a custom cutoff date for an Inventaire session's
/// `periodEnd`, instead of it silently defaulting to "now". Used both when
/// starting a new session and when editing an existing draft's period end.
Future<DateTime?> pickInventairePeriodEnd(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
}) {
  final first = firstDate ?? DateTime(2020);
  final clampedInitial =
      initialDate.isBefore(first) ? first : initialDate;
  return showDatePicker(
    context: context,
    helpText: 'Inventaire period end date',
    initialDate: clampedInitial,
    firstDate: first,
    lastDate: DateTime.now(),
    builder: (ctx, child) => Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        ),
      ),
      child: child!,
    ),
  );
}
