import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../features/auth/providers/auth_provider.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  static const _adminItems = [
    _MenuItem(
      icon: Icons.inventory_2_outlined,
      label: 'Products',
      subtitle: 'Catalogue, pricing & stock',
      color: AppColors.secondary,
      path: '/products',
    ),
    _MenuItem(
      icon: Icons.bar_chart_outlined,
      label: 'Analytics',
      subtitle: 'Daily, weekly & monthly financials',
      color: Color(0xFF00897B),
      path: '/analytics',
    ),
    _MenuItem(
      icon: Icons.warehouse_outlined,
      label: 'Inventory',
      subtitle: 'Stock levels & movements',
      color: AppColors.warning,
      path: '/inventory',
    ),
    _MenuItem(
      icon: Icons.account_balance_outlined,
      label: 'Income & Benefits',
      subtitle: 'Revenue, expenses & profit',
      color: AppColors.success,
      path: '/income',
    ),
    _MenuItem(
      icon: Icons.people_outline,
      label: 'Employees',
      subtitle: 'Team members & rewards',
      color: AppColors.primary,
      path: '/employees',
    ),
    _MenuItem(
      icon: Icons.emoji_events_outlined,
      label: 'Reward Settings',
      subtitle: 'Configure reward weights & pool',
      color: Color(0xFF7B1FA2),
      path: '/reward-settings',
    ),
    _MenuItem(
      icon: Icons.local_shipping_outlined,
      label: 'ZR Express Settings',
      subtitle: 'Shipping credentials & territory sync',
      color: Color(0xFF00695C),
      path: '/zr-settings',
    ),
  ];

  static const _employeeItems = [
    _MenuItem(
      icon: Icons.inventory_2_outlined,
      label: 'Inventory',
      subtitle: 'Stock levels & movements',
      color: AppColors.warning,
      path: '/inventory',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final appUser = userAsync.valueOrNull;
    final isAdmin = appUser?.isAdmin ?? false;
    final items = isAdmin ? _adminItems : _employeeItems;

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
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String path;
}
