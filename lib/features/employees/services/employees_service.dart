import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/employee.dart';

class EmployeesService {
  EmployeesService(this._db);

  final FirebaseFirestore _db;
  CollectionReference get _col => _db.collection('employees');
  DocumentReference get _settingsDoc =>
      _db.collection('settings').doc('rewards');

  Stream<List<Employee>> streamEmployees() => _col
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((s) => s.docs.map(Employee.fromDoc).toList());

  Stream<RewardSettings> streamSettings() =>
      _settingsDoc.snapshots().map((doc) {
        if (!doc.exists) return const RewardSettings();
        return RewardSettings.fromMap(
            doc.data() as Map<String, dynamic>);
      });

  Future<void> createEmployee(Employee employee) =>
      _col.doc(employee.id).set(employee.toMap());

  Future<void> updateEmployee(
          String id, Map<String, dynamic> data) =>
      _col.doc(id).update(data);

  Future<void> updateBenefitPercentage(String id, double pct) =>
      _col.doc(id).update({'benefitPercentage': pct});

  Future<void> updateConfirmedOrders(String id, int count) =>
      _col.doc(id).update({'confirmedOrders': count});

  Future<void> creditAmountOwed(String id, double amount) =>
      _col.doc(id).update({'amountOwed': FieldValue.increment(amount)});

  Future<void> deductAmountOwed(String id, double amount) =>
      _col.doc(id).update({'amountOwed': FieldValue.increment(-amount)});

  Future<void> deleteEmployee(String id) => _col.doc(id).delete();

  Future<void> saveSettings(RewardSettings settings) =>
      _settingsDoc.set(settings.toMap(), SetOptions(merge: true));
}
