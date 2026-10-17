/// Fine-grained permission keys an admin can grant to individual employees,
/// on top of the binary admin/employee role. Admins implicitly have every
/// permission; an employee only has the keys explicitly granted to them.
class AppPermission {
  const AppPermission._();

  static const manageEmployees = 'manage_employees';
  static const viewIncome = 'view_income';
  static const manageZrSettings = 'manage_zr_settings';
  static const managePurchases = 'manage_purchases';
  static const viewAnalytics = 'view_analytics';
  static const adjustInventory = 'adjust_inventory';
  static const manageProducts = 'manage_products';
  static const manageTasks = 'manage_tasks';

  static const all = [
    manageEmployees,
    viewIncome,
    manageZrSettings,
    managePurchases,
    viewAnalytics,
    adjustInventory,
    manageProducts,
    manageTasks,
  ];

  static String label(String key) {
    switch (key) {
      case manageEmployees:
        return 'Manage Employees';
      case viewIncome:
        return 'Income & Benefits';
      case manageZrSettings:
        return 'ZR Express Settings';
      case managePurchases:
        return 'Manage Purchases';
      case viewAnalytics:
        return 'Analytics';
      case adjustInventory:
        return 'Adjust Inventory';
      case manageProducts:
        return 'Manage Products';
      case manageTasks:
        return 'Manage Tasks';
      default:
        return key;
    }
  }

  static String description(String key) {
    switch (key) {
      case manageEmployees:
        return 'Add employees, view & edit reward settings';
      case viewIncome:
        return 'View revenue, expenses & profit';
      case manageZrSettings:
        return 'Edit ZR Express shipping credentials & territory sync';
      case managePurchases:
        return 'Create & manage purchases and purchase lists';
      case viewAnalytics:
        return 'View daily, weekly & monthly financial analytics';
      case adjustInventory:
        return 'Adjust stock & view movement history';
      case manageProducts:
        return 'Create, edit & delete products';
      case manageTasks:
        return 'Create, edit & complete tasks';
      default:
        return '';
    }
  }
}
