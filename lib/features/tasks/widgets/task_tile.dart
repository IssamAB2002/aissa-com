import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../models/task.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onStatusToggle,
    this.isAdmin = true,
  });

  final Task task;
  final VoidCallback onStatusToggle;
  final bool isAdmin;

  Color get _priorityColor => switch (task.priority) {
        TaskPriority.low => AppColors.priorityLow,
        TaskPriority.medium => AppColors.priorityMedium,
        TaskPriority.high => AppColors.priorityHigh,
        TaskPriority.urgent => AppColors.priorityUrgent,
      };

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == TaskStatus.done;
    return GestureDetector(
      onTap: isAdmin ? () => context.push('/tasks/${task.id}/edit') : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: task.isOverdue
                ? AppColors.error.withValues(alpha: 0.4)
                : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: isAdmin ? onStatusToggle : null,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? AppColors.success
                      : Colors.transparent,
                  border: Border.all(
                    color: isDone
                        ? AppColors.success
                        : AppColors.divider,
                    width: 2,
                  ),
                ),
                child: isDone
                    ? const Icon(Icons.check,
                        size: 14, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style:
                        Theme.of(context).textTheme.bodyLarge?.copyWith(
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isDone
                                  ? AppColors.textSecondary
                                  : null,
                            ),
                  ),
                  if (task.dueDate != null)
                    Text(
                      'Due ${DateFormat('MMM d').format(task.dueDate!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: task.isOverdue
                            ? AppColors.error
                            : AppColors.textSecondary,
                        fontWeight: task.isOverdue
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _priorityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                task.priority.label,
                style: TextStyle(
                  color: _priorityColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
