import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../models/task.dart';
import '../providers/tasks_provider.dart';
import '../widgets/task_tile.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(tasksStreamProvider);
    await Future.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksStreamProvider);
    final isAdmin =
        ref.watch(currentUserProvider).valueOrNull?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile',
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'To Do'),
            Tab(text: 'In Progress'),
            Tab(text: 'Done'),
          ],
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/tasks/new'),
              icon: const Icon(Icons.add),
              label: const Text('New Task'),
            )
          : null,
      body: Column(
        children: [
          if (!isAdmin)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              color: AppColors.secondary.withValues(alpha: 0.08),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined,
                      size: 16, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Text(
                    'View only — tasks can only be managed by admins.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondary
                          .withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: tasksAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (tasks) {
                final todo = tasks
                    .where((t) => t.status == TaskStatus.todo)
                    .toList();
                final inProgress = tasks
                    .where((t) => t.status == TaskStatus.inProgress)
                    .toList();
                final done = tasks
                    .where((t) => t.status == TaskStatus.done)
                    .toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _TaskList(
                      tasks: todo,
                      emptyTitle: 'No tasks to do',
                      isAdmin: isAdmin,
                      ref: ref,
                      onRefresh: _refresh,
                    ),
                    _TaskList(
                      tasks: inProgress,
                      emptyTitle: 'Nothing in progress',
                      isAdmin: isAdmin,
                      ref: ref,
                      onRefresh: _refresh,
                    ),
                    _TaskList(
                      tasks: done,
                      emptyTitle: 'No completed tasks yet',
                      isAdmin: isAdmin,
                      ref: ref,
                      onRefresh: _refresh,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.tasks,
    required this.emptyTitle,
    required this.isAdmin,
    required this.ref,
    required this.onRefresh,
  });
  final List<Task> tasks;
  final String emptyTitle;
  final bool isAdmin;
  final WidgetRef ref;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (ctx, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: EmptyState(
                icon: Icons.task_alt_outlined,
                title: emptyTitle,
              ),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: tasks.length,
        itemBuilder: (context, i) => TaskTile(
          task: tasks[i],
          isAdmin: isAdmin,
          onStatusToggle: () {
            final next = tasks[i].status == TaskStatus.todo
                ? TaskStatus.inProgress
                : tasks[i].status == TaskStatus.inProgress
                    ? TaskStatus.done
                    : TaskStatus.todo;
            ref
                .read(tasksServiceProvider)
                .updateStatus(tasks[i].id, next);
          },
        ),
      ),
    );
  }
}
