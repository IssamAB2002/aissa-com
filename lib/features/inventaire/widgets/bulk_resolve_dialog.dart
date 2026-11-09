import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum _ItemStatus { waiting, processing, success, failed }

class BulkResolveItem {
  const BulkResolveItem({required this.label, required this.action});
  final String label;
  final Future<void> Function() action;
}

class BulkResolveResult {
  const BulkResolveResult({required this.succeeded, required this.failed});
  final int succeeded;
  final int failed;
}

/// Runs each item's action sequentially, showing a progress list — mirrors
/// the Purchases feature's `MultiStatusDialog` pattern, generalized to any
/// kind of item (used here for orders and purchases alike).
class BulkResolveDialog extends StatefulWidget {
  const BulkResolveDialog({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<BulkResolveItem> items;

  static Future<BulkResolveResult> show(
    BuildContext context, {
    required String title,
    required List<BulkResolveItem> items,
  }) async {
    final result = await showDialog<BulkResolveResult>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => BulkResolveDialog(title: title, items: items),
    );
    return result ?? const BulkResolveResult(succeeded: 0, failed: 0);
  }

  @override
  State<BulkResolveDialog> createState() => _BulkResolveDialogState();
}

class _BulkResolveDialogState extends State<BulkResolveDialog> {
  final List<_ItemStatus> _statuses = [];
  int _currentIndex = -1;

  @override
  void initState() {
    super.initState();
    _statuses.addAll(List.filled(widget.items.length, _ItemStatus.waiting));
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    var succeeded = 0;
    var failed = 0;
    for (var i = 0; i < widget.items.length; i++) {
      setState(() {
        _currentIndex = i;
        _statuses[i] = _ItemStatus.processing;
      });
      try {
        await widget.items[i].action();
        setState(() {
          _statuses[i] = _ItemStatus.success;
          succeeded++;
        });
      } catch (_) {
        setState(() {
          _statuses[i] = _ItemStatus.failed;
          failed++;
        });
      }
    }
    if (!mounted) return;
    Navigator.of(context)
        .pop(BulkResolveResult(succeeded: succeeded, failed: failed));
  }

  Widget _statusIcon(_ItemStatus status) {
    switch (status) {
      case _ItemStatus.waiting:
        return const Icon(Icons.remove, size: 16, color: AppColors.textHint);
      case _ItemStatus.processing:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _ItemStatus.success:
        return const Icon(Icons.check_circle,
            size: 16, color: AppColors.success);
      case _ItemStatus.failed:
        return const Icon(Icons.cancel, size: 16, color: AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    final inProgress = _currentIndex >= 0 && _currentIndex < total;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    inProgress
                        ? 'Processing ${_currentIndex + 1} of $total…'
                        : 'Preparing $total item(s)…',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: total,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.cardBorder),
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            _statusIcon(_statuses[i]),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.items[i].label,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
