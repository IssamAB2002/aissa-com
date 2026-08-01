import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus { todo, inProgress, done }

enum TaskPriority { low, medium, high, urgent }

extension TaskStatusX on TaskStatus {
  String get label => switch (this) {
        TaskStatus.todo => 'To Do',
        TaskStatus.inProgress => 'In Progress',
        TaskStatus.done => 'Done',
      };
}

extension TaskPriorityX on TaskPriority {
  String get label => switch (this) {
        TaskPriority.low => 'Low',
        TaskPriority.medium => 'Medium',
        TaskPriority.high => 'High',
        TaskPriority.urgent => 'Urgent',
      };
}

class Task {
  const Task({
    required this.id,
    required this.title,
    this.description,
    required this.priority,
    required this.status,
    this.dueDate,
    this.assignedTo,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime? dueDate;
  final String? assignedTo;
  final DateTime createdAt;

  bool get isOverdue =>
      dueDate != null &&
      dueDate!.isBefore(DateTime.now()) &&
      status != TaskStatus.done;

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'priority': priority.name,
        'status': status.name,
        'dueDate':
            dueDate != null ? Timestamp.fromDate(dueDate!) : null,
        'assignedTo': assignedTo,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory Task.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      title: m['title'] as String,
      description: m['description'] as String?,
      priority:
          TaskPriority.values.byName(m['priority'] as String),
      status: TaskStatus.values.byName(m['status'] as String),
      dueDate: (m['dueDate'] as Timestamp?)?.toDate(),
      assignedTo: m['assignedTo'] as String?,
      createdAt: (m['createdAt'] as Timestamp).toDate(),
    );
  }

  Task copyWith({
    String? title,
    String? description,
    TaskPriority? priority,
    TaskStatus? status,
    DateTime? dueDate,
    String? assignedTo,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        dueDate: dueDate ?? this.dueDate,
        assignedTo: assignedTo ?? this.assignedTo,
        createdAt: createdAt,
      );
}
