import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../features/auth/models/app_permission.dart';
import '../../../features/auth/providers/auth_provider.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  // Directory bundles several admin screens with no per-tab gating, so it
  // only appears for full admins; permitted employees reach the individual
  // screens below directly.
  static const _directoryItem = _MenuItem(
    icon: Icons.folder_shared_outlined,
    label: 'Directory',
    subtitle: 'Products, inventory, employees, rewards & suppliers',
    color: AppColors.secondary,
    path: '/directory',
  );

  static const _permissionItems = [
    _MenuItem(
      icon: Icons.bar_chart_outlined,
      label: 'Analytics',
      subtitle: 'Daily, weekly & monthly financials',
      color: Color(0xFF00897B),
      path: '/analytics',
      permission: AppPermission.viewAnalytics,
    ),
    _MenuItem(
      icon: Icons.account_balance_outlined,
      label: 'Income & Benefits',
      subtitle: 'Revenue, expenses & profit',
      color: AppColors.success,
      path: '/income',
      permission: AppPermission.viewIncome,
    ),
    _MenuItem(
      icon: Icons.people_outline,
      label: 'Employees',
      subtitle: 'Manage employees & reward settings',
      color: AppColors.primary,
      path: '/employees',
      permission: AppPermission.manageEmployees,
    ),
    _MenuItem(
      icon: Icons.local_shipping_outlined,
      label: 'ZR Express Settings',
      subtitle: 'Shipping credentials & territory sync',
      color: Color(0xFF00695C),
      path: '/zr-settings',
      permission: AppPermission.manageZrSettings,
    ),
    _MenuItem(
      icon: Icons.checklist_outlined,
      label: 'Purchase Lists',
      subtitle: 'Generate & track supplier purchase lists',
      color: Color(0xFF6D4C41),
      path: '/purchase-lists',
      permission: AppPermission.managePurchases,
    ),
  ];

  static const _inventoryItem = _MenuItem(
    icon: Icons.inventory_2_outlined,
    label: 'Inventory',
    subtitle: 'Stock levels & movements',
    color: AppColors.warning,
    path: '/inventory',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final appUser = userAsync.valueOrNull;
    final isAdmin = appUser?.isAdmin ?? false;
    final items = [
      if (isAdmin) _directoryItem,
      ..._permissionItems.where(
          (item) => appUser?.hasPermission(item.permission!) ?? false),
      _inventoryItem,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Account',
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!isAdmin) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.secondary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Some features are only available to admins.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          ...items.map(
            (item) => GestureDetector(
              onTap: () => context.push(item.path),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          Icon(item.icon, color: item.color, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.label,
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          Text(item.subtitle,
                              style:
                                  Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.textHint),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.path,
    this.permission,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String path;
  final String? permission;
}
