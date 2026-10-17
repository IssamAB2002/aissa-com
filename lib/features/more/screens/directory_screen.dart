import 'package:flutter/material.dart';

import '../../employees/screens/employees_screen.dart';
import '../../employees/screens/reward_settings_screen.dart';
import '../../inventory/screens/inventory_screen.dart';
import '../../products/screens/products_screen.dart';
import '../../suppliers/screens/suppliers_screen.dart';

/// Groups the master-data screens (Products, Inventory, Employees, Reward
/// Settings & Suppliers) behind a single "Directory" entry in More, instead
/// of five separate menu cards. Each tab is rendered `embedded` so it drops
/// its own app bar — Directory's app bar + tab bar is the only one shown.
class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Directory'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Products'),
            Tab(text: 'Inventory'),
            Tab(text: 'Employees'),
            Tab(text: 'Reward Settings'),
            Tab(text: 'Suppliers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ProductsScreen(embedded: true),
          InventoryScreen(embedded: true),
          EmployeesScreen(embedded: true),
          RewardSettingsScreen(embedded: true),
          SuppliersScreen(embedded: true),
        ],
      ),
    );
  }
}
