import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key, this.from});

  /// The blocked route path (e.g. '/income', '/purchases').
  final String? from;

  static const _pageNames = <String, String>{
    '/income': 'Income & Benefits',
    '/income/new': 'Add Transaction',
    '/employees': 'Employees',
    '/reward-settings': 'Reward Settings',
    '/purchases': 'Purchases',
    '/purchases/new': 'New Purchase',
    '/inventory/adjust': 'Stock Adjustment',
    '/inventory/movements': 'Stock Movement History',
    '/tasks/new': 'New Task',
    '/products/new': 'Add Product',
  };

  String get _label {
    if (from == null) return 'This page';
    // Exact match first
    if (_pageNames.containsKey(from)) return _pageNames[from]!;
    // Prefix match for dynamic routes (e.g. /employees/xyz, /purchases/xyz)
    for (final entry in _pageNames.entries) {
      if (from!.startsWith(entry.key)) return entry.value;
    }
    // Edit routes
    if (from!.endsWith('/edit') && from!.startsWith('/tasks/')) return 'Edit Task';
    if (from!.endsWith('/edit') && from!.startsWith('/products/')) return 'Edit Product';
    if (from!.startsWith('/purchases/')) return 'Purchase Details';
    if (from!.startsWith('/employees/')) return 'Employee Details';
    return 'This page';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 54,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              const Text(
                'Access Restricted',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Page-specific subtitle
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                  children: [
                    TextSpan(
                      text: _label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const TextSpan(
                      text:
                          ' is restricted to admin accounts only.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Info banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.warning, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'You are logged in as an Employee. Contact your administrator if you need access to this section.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Back button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/dashboard');
                    }
                  },
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text(
                    'Go Back',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Dashboard shortcut
              TextButton(
                onPressed: () => context.go('/dashboard'),
                child: const Text(
                  'Go to Dashboard',
                  style: TextStyle(color: AppColors.primaryLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
