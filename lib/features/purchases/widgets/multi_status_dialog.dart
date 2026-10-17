import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/purchase.dart';
import '../services/purchases_service.dart';

enum MultiPurchaseAction { markReceived, confirmPayment }

enum _ItemStatus { waiting, processing, success, failed }

class MultiStatusResult {
  const MultiStatusResult({required this.succeeded, required this.failed});
  final int succeeded;
  final int failed;
}

/// Bulk-applies [action] to [purchases] one by one, showing a spinner next
/// to whichever is currently being updated — mirrors the Multi-ZR send
/// dialog's progress UI.
class MultiStatusDialog extends StatefulWidget {
  const MultiStatusDialog({
    super.key,
    required this.purchases,
    required this.action,
    required this.service,
  });

  final List<Purchase> purchases;
  final MultiPurchaseAction action;
  final PurchasesService service;

  static Future<MultiStatusResult> show(
    BuildContext context, {
    required List<Purchase> purchases,
    required MultiPurchaseAction action,
    required PurchasesService service,
  }) async {
    final result = await showDialog<MultiStatusResult>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => MultiStatusDialog(
          purchases: purchases, action: action, service: service),
    );
    return result ?? const MultiStatusResult(succeeded: 0, failed: 0);
  }

  @override
  State<MultiStatusDialog> createState() => _MultiStatusDialogState();
}

class _MultiStatusDialogState extends State<MultiStatusDialog> {
  final List<_ItemStatus> _statuses = [];
  int _currentIndex = -1;

  String get _title => widget.action == MultiPurchaseAction.markReceived
      ? 'Marking as Received'
      : 'Confirming Payment';

  @override
  void initState() {
    super.initState();
    _statuses.addAll(List.filled(widget.purchases.length, _ItemStatus.waiting));
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    var succeeded = 0;
    var failed = 0;

    for (var i = 0; i < widget.purchases.length; i++) {
      setState(() {
        _currentIndex = i;
        _statuses[i] = _ItemStatus.processing;
      });
      try {
        if (widget.action == MultiPurchaseAction.markReceived) {
          await widget.service
              .updateStatus(widget.purchases[i], PurchaseStatus.received);
        } else {
          await widget.service.confirmPayment(widget.purchases[i]);
        }
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
        .pop(MultiStatusResult(succeeded: succeeded, failed: failed));
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
    final total = widget.purchases.length;
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
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(Icons.price_check,
                        color: AppColors.primary, size: 30),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _title,
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
                        ? 'Updating purchase ${_currentIndex + 1} of $total…'
                        : 'Preparing $total purchase(s)…',
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
                      itemBuilder: (context, i) {
                        final purchase = widget.purchases[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              _statusIcon(_statuses[i]),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${purchase.supplierName ?? 'No supplier'} · #${purchase.id.substring(0, 8).toUpperCase()}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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
