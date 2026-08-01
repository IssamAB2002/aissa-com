import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../models/task.dart';
import '../providers/tasks_provider.dart';

class AddEditTaskScreen extends ConsumerStatefulWidget {
  const AddEditTaskScreen({super.key, this.taskId});
  final String? taskId;

  @override
  ConsumerState<AddEditTaskScreen> createState() =>
      _AddEditTaskScreenState();
}

class _AddEditTaskScreenState
    extends ConsumerState<AddEditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _assignedCtrl = TextEditingController();

  TaskPriority _priority = TaskPriority.medium;
  TaskStatus _status = TaskStatus.todo;
  DateTime? _dueDate;
  bool _saving = false;
  bool _loaded = false;

  bool get _isEdit => widget.taskId != null;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _assignedCtrl.dispose();
    super.dispose();
  }

  void _loadTask(Task t) {
    if (_loaded) return;
    _loaded = true;
    _titleCtrl.text = t.title;
    _descCtrl.text = t.description ?? '';
    _assignedCtrl.text = t.assignedTo ?? '';
    _priority = t.priority;
    _status = t.status;
    _dueDate = t.dueDate;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final service = ref.read(tasksServiceProvider);

    try {
      if (_isEdit) {
        await service.updateTask(widget.taskId!, {
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          'priority': _priority.name,
          'status': _status.name,
          'dueDate': _dueDate,
          'assignedTo': _assignedCtrl.text.trim().isEmpty
              ? null
              : _assignedCtrl.text.trim(),
        });
      } else {
        final task = Task(
          id: const Uuid().v4(),
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          priority: _priority,
          status: _status,
          dueDate: _dueDate,
          assignedTo: _assignedCtrl.text.trim().isEmpty
              ? null
              : _assignedCtrl.text.trim(),
          createdAt: DateTime.now(),
        );
        await service.createTask(task);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save task: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit) {
      ref.watch(tasksStreamProvider).whenData((tasks) {
        final idx = tasks.indexWhere((t) => t.id == widget.taskId);
        if (idx >= 0) _loadTask(tasks[idx]);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Task' : 'New Task'),
        actions: _isEdit
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await AppConfirmDialog.show(
                      context,
                      icon: Icons.delete_outline,
                      iconColor: AppColors.error,
                      title: 'Delete Task',
                      message: 'This action cannot be undone.',
                      confirmLabel: 'Delete',
                    );
                    if (ok == true && context.mounted) {
                      await ref
                          .read(tasksServiceProvider)
                          .deleteTask(widget.taskId!);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
              ]
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title *'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                  labelText: 'Description (optional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Text('Priority',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: TaskPriority.values.asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  final selected = _priority == p;
                  final color = switch (p) {
                    TaskPriority.low => AppColors.priorityLow,
                    TaskPriority.medium => AppColors.priorityMedium,
                    TaskPriority.high => AppColors.priorityHigh,
                    TaskPriority.urgent => AppColors.priorityUrgent,
                  };
                  return Padding(
                    padding: EdgeInsets.only(
                        right: i < TaskPriority.values.length - 1 ? 8 : 0),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _priority = p),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? color : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  selected ? color : AppColors.cardBorder,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            p.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            Text('Status',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: TaskStatus.values.asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  final selected = _status == s;
                  return Padding(
                    padding: EdgeInsets.only(
                        right: i < TaskStatus.values.length - 1 ? 8 : 0),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _status = s),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.cardBorder,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            s.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Due Date'),
              subtitle: Text(_dueDate != null
                  ? DateFormat('MMM d, y').format(_dueDate!)
                  : 'Not set'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_dueDate != null)
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.textHint),
                      onPressed: () =>
                          setState(() => _dueDate = null),
                    ),
                  const Icon(Icons.calendar_today_outlined),
                ],
              ),
              onTap: _pickDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.divider),
              ),
              tileColor: Colors.white,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _assignedCtrl,
              decoration: const InputDecoration(
                  labelText: 'Assign to (optional)'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(_isEdit ? 'Save Changes' : 'Create Task'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
