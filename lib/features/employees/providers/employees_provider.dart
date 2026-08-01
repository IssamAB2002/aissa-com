import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/employee.dart';
import '../services/employees_service.dart';

final employeesServiceProvider =
    Provider((ref) => EmployeesService(FirebaseFirestore.instance));

final employeesStreamProvider = StreamProvider<List<Employee>>((ref) {
  return ref.watch(employeesServiceProvider).streamEmployees();
});

final rewardSettingsProvider = StreamProvider<RewardSettings>((ref) {
  return ref.watch(employeesServiceProvider).streamSettings();
});
