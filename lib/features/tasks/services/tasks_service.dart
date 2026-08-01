import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/task.dart';

class TasksService {
  TasksService(this._db);

  final FirebaseFirestore _db;
  CollectionReference get _col => _db.collection('tasks');

  Stream<List<Task>> streamTasks() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Task.fromDoc).toList());

  Future<void> createTask(Task task) async {
    final id = const Uuid().v4();
    await _col.doc(id).set(task.toMap());
  }

  Future<void> updateTask(String id, Map<String, dynamic> data) =>
      _col.doc(id).update(data);

  Future<void> updateStatus(String id, TaskStatus status) =>
      _col.doc(id).update({'status': status.name});

  Future<void> deleteTask(String id) => _col.doc(id).delete();
}
