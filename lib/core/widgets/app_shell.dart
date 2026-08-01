import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../features/auth/models/app_user.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/services/auth_service.dart';
import '../providers/connectivity_provider.dart';
import '../theme/app_colors.dart';
import 'app_confirm_dialog.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _adminTabs = [
    _NavTab(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      path: '/dashboard',
    ),
    _NavTab(
      label: 'Orders',
      icon: Icons.shopping_bag_outlined,
      activeIcon: Icons.shopping_bag,
      path: '/orders',
    ),
    _NavTab(
      label: 'Purchases',
      icon: Icons.local_shipping_outlined,
      activeIcon: Icons.local_shipping,
      path: '/purchases',
    ),
    _NavTab(
      label: 'Tasks',
      icon: Icons.task_alt_outlined,
      activeIcon: Icons.task_alt,
      path: '/tasks',
    ),
    _NavTab(
      label: 'More',
      icon: Icons.more_horiz,
      activeIcon: Icons.more_horiz,
      path: '/more',
    ),
  ];

  static const _employeeTabs = [
    _NavTab(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      path: '/dashboard',
    ),
    _NavTab(
      label: 'Orders',
      icon: Icons.shopping_bag_outlined,
      activeIcon: Icons.shopping_bag,
      path: '/orders',
    ),
    _NavTab(
      label: 'Products',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
      path: '/products',
    ),
    _NavTab(
      label: 'Tasks',
      icon: Icons.task_alt_outlined,
      activeIcon: Icons.task_alt,
      path: '/tasks',
    ),
    _NavTab(
      label: 'Inventory',
      icon: Icons.warehouse_outlined,
      activeIcon: Icons.warehouse,
      path: '/inventory',
    ),
  ];

  // Routes under More that should highlight the More tab when active.
  // For employees: only _employeeTabs are used, so this only affects admins
  // For admins: products and inventory are accessed via More menu, so highlight More tab
  static const _moreRoutes = [
    '/products',
    '/inventory',
    '/income',
    '/employees',
    '/reward-settings',
  ];

  int _currentIndex(BuildContext context, List<_NavTab> tabs) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < tabs.length; i++) {
      if (location.startsWith(tabs[i].path)) return i;
    }
    if (_moreRoutes.any((r) => location.startsWith(r))) {
      final moreIdx = tabs.indexWhere((t) => t.path == '/more');
      if (moreIdx >= 0) return moreIdx;
    }
    return 0;
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await AppConfirmDialog.show(
      context,
      icon: Icons.logout_rounded,
      iconColor: AppColors.error,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign Out',
    );
    if (ok == true && context.mounted) {
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final appUser = userAsync.valueOrNull;
    final isAdmin = appUser?.isAdmin ?? false;
    final tabs = isAdmin ? _adminTabs : _employeeTabs;
    final index = _currentIndex(context, tabs);
    final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;

    return Scaffold(
      body: Column(
        children: [
          if (!isOnline)
            Container(
              width: double.infinity,
              color: AppColors.warning,
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 13, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'You\'re offline — showing cached data',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (i) => context.go(tabs[i].path),
          items: tabs
              .map(
                (t) => BottomNavigationBarItem(
                  icon: Icon(t.icon),
                  activeIcon: Icon(t.activeIcon),
                  label: t.label,
                ),
              )
              .toList(),
        ),
      ),
      endDrawer: _ProfileDrawer(
        appUser: appUser,
        onSignOut: () => _confirmSignOut(context, ref),
        onNavigate: (path) {
          Navigator.pop(context);
          context.push(path);
        },
      ),
    );
  }
}

class _NavTab {
  const _NavTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
  });
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;
}

// ── Profile Drawer ────────────────────────────────────────────────────────────

class _ProfileDrawer extends StatelessWidget {
  const _ProfileDrawer({
    required this.appUser,
    required this.onSignOut,
    required this.onNavigate,
  });

  final AppUser? appUser;
  final VoidCallback onSignOut;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final user = appUser;
    final isAdmin = user?.isAdmin ?? false;
    final name = user?.displayName ?? '—';
    final email = user?.email ?? '';
    final memberSince = user != null
        ? DateFormat('MMMM y').format(user.createdAt)
        : '—';

    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          _DrawerHeader(
            name: name,
            email: email,
            isAdmin: isAdmin,
            onClose: () => Navigator.pop(context),
          ),

          // ── Scrollable body ─────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              children: [
                // Account info card
                _SectionLabel('MY ACCOUNT'),
                const SizedBox(height: 8),
                _InfoCard(children: [
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Name',
                    value: name,
                  ),
                  _InfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: email,
                    isLast: true,
                  ),
                ]),
                const SizedBox(height: 6),
                // Member since sub-card
                _InfoCard(children: [
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Member since',
                    value: memberSince,
                    isLast: true,
                  ),
                ]),

                // Admin quick-access
                if (isAdmin) ...[
                  const SizedBox(height: 24),
                  _SectionLabel('ADMINISTRATION'),
                  const SizedBox(height: 8),
                  _NavCard(children: [
                    _NavRow(
                      icon: Icons.account_balance_outlined,
                      label: 'Income & Benefits',
                      iconColor: AppColors.success,
                      onTap: () => onNavigate('/income'),
                    ),
                    _NavRow(
                      icon: Icons.people_outline,
                      label: 'Employees',
                      iconColor: AppColors.primary,
                      onTap: () => onNavigate('/employees'),
                    ),
                    _NavRow(
                      icon: Icons.emoji_events_outlined,
                      label: 'Reward Settings',
                      iconColor: const Color(0xFF7B1FA2),
                      isLast: true,
                      onTap: () => onNavigate('/reward-settings'),
                    ),
                  ]),
                ],
              ],
            ),
          ),

          // ── Footer ──────────────────────────────────────────────────
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // App brand
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(Icons.storefront_outlined,
                          color: Colors.white, size: 12),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Aissa Com',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Sign Out button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onSignOut();
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          // Safe area bottom padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ── Drawer sub-widgets ────────────────────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.name,
    required this.email,
    required this.isAdmin,
    required this.onClose,
  });

  final String name;
  final String email;
  final bool isAdmin;
  final VoidCallback onClose;

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A237E), // primary
            Color(0xFF283593), // slightly lighter navy
            Color(0xFF3949AB), // primaryLight
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(height: 8),

              // Avatar
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isAdmin
                        ? [Colors.amber.shade600, Colors.orange.shade700]
                        : [AppColors.secondary, const Color(0xFF0288D1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _initials(name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Name
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),

              // Email
              Text(
                email,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Role badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isAdmin
                      ? Colors.amber.withValues(alpha: 0.25)
                      : AppColors.secondary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isAdmin
                        ? Colors.amber.withValues(alpha: 0.6)
                        : AppColors.secondary.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAdmin
                          ? Icons.admin_panel_settings_outlined
                          : Icons.badge_outlined,
                      color: isAdmin ? Colors.amber : AppColors.secondary,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isAdmin ? 'Administrator' : 'Employee',
                      style: TextStyle(
                        color: isAdmin ? Colors.amber : AppColors.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textHint,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 58, endIndent: 0),
      ],
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(12),
            bottom: isLast ? const Radius.circular(12) : Radius.zero,
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textHint),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 58, endIndent: 0),
      ],
    );
  }
}
