import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../services/tasks_service.dart';

final tasksServiceProvider =
    Provider((ref) => TasksService(FirebaseFirestore.instance));

final tasksStreamProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(tasksServiceProvider).streamTasks();
});
