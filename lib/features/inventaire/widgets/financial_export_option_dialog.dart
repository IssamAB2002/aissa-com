import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum FinancialExportOption { none, daily, weekly, monthly, all }

extension FinancialExportOptionLabel on FinancialExportOption {
  String get label => switch (this) {
        FinancialExportOption.none => 'None',
        FinancialExportOption.daily => 'Daily',
        FinancialExportOption.weekly => 'Weekly',
        FinancialExportOption.monthly => 'Monthly',
        FinancialExportOption.all => 'Everything (all sheets)',
      };
}

/// Lets the admin choose which Financial Situation breakdown(s), if any, to
/// bundle into the Inventaire Excel export alongside the existing Stock
/// Valuation and Orders/Purchases sheets.
Future<FinancialExportOption?> showFinancialExportOptionDialog(
  BuildContext context,
) {
  var selected = FinancialExportOption.none;
  return showDialog<FinancialExportOption>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Export to Excel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Include Financial Situation:',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            RadioGroup<FinancialExportOption>(
              groupValue: selected,
              onChanged: (v) => setState(() => selected = v!),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in FinancialExportOption.values)
                    RadioListTile<FinancialExportOption>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(option.label),
                      value: option,
                      activeColor: AppColors.primary,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, selected),
            child: const Text('Export'),
          ),
        ],
      ),
    ),
  );
}
