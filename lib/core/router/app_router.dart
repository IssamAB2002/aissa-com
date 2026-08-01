import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/analytics/screens/analytics_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/admin_login_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/employees/screens/employee_detail_screen.dart';
import '../../features/employees/screens/employees_screen.dart';
import '../../features/employees/screens/reward_settings_screen.dart';
import '../../features/income/screens/add_transaction_screen.dart';
import '../../features/income/screens/income_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/inventory/screens/movements_screen.dart';
import '../../features/inventory/screens/stock_adjustment_screen.dart';
import '../../features/products/models/product.dart';
import '../../features/more/screens/more_screen.dart';
import '../../features/orders/screens/create_order_screen.dart';
import '../../features/purchases/screens/create_purchase_screen.dart';
import '../../features/purchases/screens/purchase_detail_screen.dart';
import '../../features/purchases/screens/purchases_screen.dart';
import '../../features/orders/screens/order_detail_screen.dart';
import '../../features/orders/screens/orders_screen.dart';
import '../../features/products/screens/add_edit_product_screen.dart';
import '../../features/products/screens/product_detail_screen.dart';
import '../../features/products/screens/products_screen.dart';
import '../../features/shipping/screens/zr_settings_screen.dart';
import '../../features/tasks/screens/add_edit_task_screen.dart';
import '../../features/tasks/screens/tasks_screen.dart';
import '../screens/access_denied_screen.dart';
import '../widgets/app_shell.dart';

/// Builds an access-denied redirect path for a blocked route.
String _denied(String blockedPath) =>
    '/access-denied?from=${Uri.encodeQueryComponent(blockedPath)}';

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(Ref ref) {
    ref.listen(firebaseAuthStateProvider, (_, __) => notifyListeners());
    ref.listen(currentUserProvider, (_, __) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authAsync = ref.read(firebaseAuthStateProvider);
      final userAsync = ref.read(currentUserProvider);

      final loc = state.matchedLocation;

      // Still loading auth state → hold on splash.
      // /admin-login is excluded: the screen handles its own sign-in flow and
      // must not be torn down mid-flight while it checks the employee role.
      if (authAsync.isLoading || userAsync.isLoading) {
        if (loc == '/splash' || loc == '/admin-login') return null;
        return '/splash';
      }

      final firebaseUser = authAsync.valueOrNull;
      final appUser = userAsync.valueOrNull;

      // Not signed in → go to login
      if (firebaseUser == null && appUser == null) {
        return loc == '/login' || loc == '/admin-login' ? null : '/login';
      }

      // Signed in but profile not yet in Firestore → stay on splash.
      // /admin-login is excluded so the screen is never torn down mid sign-in
      // before it can read the role and show the employee warning.
      if (appUser == null) {
        if (loc == '/admin-login') return null;
        return loc == '/splash' ? null : '/splash';
      }

      // Authenticated — redirect away from auth screens.
      // Exception: employees who land on /admin-login are NOT redirected here;
      // the AdminLoginScreen detects the role and handles the warning + sign-out itself.
      if (loc == '/login' || loc == '/splash') return '/dashboard';
      if (loc == '/admin-login' && appUser.isAdmin) return '/dashboard';

      // Employees cannot access admin-only routes → show access denied
      if (appUser.isEmployee) {
        // Never block the access-denied screen itself
        if (loc.startsWith('/access-denied')) return null;

        const adminOnlyPrefixes = [
          '/income',
          '/employees',
          '/reward-settings',
          '/zr-settings',
          '/purchases',
          '/analytics',
        ];
        for (final prefix in adminOnlyPrefixes) {
          if (loc.startsWith(prefix)) return _denied(loc);
        }
        // Inventory: no stock adjustments or movement history
        if (loc == '/inventory/adjust') return _denied(loc);
        if (loc == '/inventory/movements') return _denied(loc);
        // Tasks: view-only — block add and edit
        if (loc == '/tasks/new') return _denied(loc);
        if (loc.startsWith('/tasks/') && loc.endsWith('/edit')) {
          return _denied(loc);
        }
        // Products: view-only — block add and edit
        if (loc == '/products/new') return _denied(loc);
        if (loc.startsWith('/products/') && loc.endsWith('/edit')) {
          return _denied(loc);
        }
      }

      return null;
    },
    routes: [
      // Auth
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/admin-login', builder: (c, s) => const AdminLoginScreen()),

      // Access denied — shown to employees who navigate to admin-only routes
      GoRoute(
        path: '/access-denied',
        builder: (c, s) => AccessDeniedScreen(
          from: s.uri.queryParameters['from'],
        ),
      ),

      // Shell: bottom nav tabs
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
              path: '/dashboard',
              builder: (c, s) => const DashboardScreen()),
          GoRoute(
              path: '/orders', builder: (c, s) => const OrdersScreen()),
          GoRoute(
              path: '/products',
              builder: (c, s) => const ProductsScreen()),
          GoRoute(
              path: '/inventory',
              builder: (c, s) => const InventoryScreen()),
          GoRoute(path: '/tasks', builder: (c, s) => const TasksScreen()),
          GoRoute(
              path: '/purchases',
              builder: (c, s) => const PurchasesScreen()),
          GoRoute(path: '/more', builder: (c, s) => const MoreScreen()),
        ],
      ),

      // Orders
      GoRoute(
          path: '/orders/new', builder: (c, s) => const CreateOrderScreen()),
      GoRoute(
        path: '/orders/:id',
        builder: (c, s) =>
            OrderDetailScreen(orderId: s.pathParameters['id']!),
      ),

      // Products
      GoRoute(
          path: '/products/new',
          builder: (c, s) => const AddEditProductScreen()),
      GoRoute(
        path: '/products/:id',
        builder: (c, s) =>
            ProductDetailScreen(productId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/products/:id/edit',
        builder: (c, s) =>
            AddEditProductScreen(productId: s.pathParameters['id']),
      ),

      // Inventory (sub-routes: adjust and movements)
      GoRoute(
          path: '/inventory/adjust',
          builder: (c, s) => StockAdjustmentScreen(
                initialProduct: s.extra as Product?,
              )),
      GoRoute(
          path: '/inventory/movements',
          builder: (c, s) => const MovementsScreen()),

      // Income (admin only — router blocks employees)
      GoRoute(path: '/income', builder: (c, s) => const IncomeScreen()),
      GoRoute(
          path: '/income/new',
          builder: (c, s) => const AddTransactionScreen()),

      // Tasks
      GoRoute(
          path: '/tasks/new', builder: (c, s) => const AddEditTaskScreen()),
      GoRoute(
        path: '/tasks/:id/edit',
        builder: (c, s) =>
            AddEditTaskScreen(taskId: s.pathParameters['id']),
      ),

      // Purchases (admin only — router blocks employees)
      GoRoute(
          path: '/purchases/new',
          builder: (c, s) => const CreatePurchaseScreen()),
      GoRoute(
        path: '/purchases/:id',
        builder: (c, s) =>
            PurchaseDetailScreen(purchaseId: s.pathParameters['id']!),
      ),

      // Analytics (admin only — router blocks employees)
      GoRoute(
          path: '/analytics',
          builder: (c, s) => const AnalyticsScreen()),

      // Employees (admin only — router blocks employees)
      GoRoute(
          path: '/employees', builder: (c, s) => const EmployeesScreen()),
      GoRoute(
        path: '/employees/:id',
        builder: (c, s) =>
            EmployeeDetailScreen(employeeId: s.pathParameters['id']!),
      ),
      GoRoute(
          path: '/reward-settings',
          builder: (c, s) => const RewardSettingsScreen()),

      // ZR Express settings (admin only — router blocks employees)
      GoRoute(
          path: '/zr-settings',
          builder: (c, s) => const ZrSettingsScreen()),
    ],
  );
});
