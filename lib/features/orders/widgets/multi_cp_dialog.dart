import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../shipping/providers/shipping_reference_provider.dart';
import '../models/order.dart';
import '../services/orders_service.dart';

enum _RowStatus { waiting, checking, eligible, notEligible, failed, confirmed }

enum _Phase { checking, review, confirming, done }

class MultiCpResult {
  const MultiCpResult({
    required this.checked,
    required this.eligible,
    required this.confirmed,
    required this.failed,
    this.errorMessage,
  });

  final int checked;
  final int eligible;
  final int confirmed;
  final int failed;
  final String? errorMessage;
}

class MultiCpDialog extends ConsumerStatefulWidget {
  const MultiCpDialog({
    super.key,
    required this.orders,
    required this.service,
  });

  final List<Order> orders;
  final OrdersService service;

  static Future<MultiCpResult?> show(
    BuildContext context, {
    required List<Order> orders,
    required OrdersService service,
  }) {
    return showDialog<MultiCpResult>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => MultiCpDialog(orders: orders, service: service),
    );
  }

  @override
  ConsumerState<MultiCpDialog> createState() => _MultiCpDialogState();
}

class _MultiCpDialogState extends ConsumerState<MultiCpDialog> {
  final List<_RowStatus> _statuses = [];
  _Phase _phase = _Phase.checking;
  int _currentIndex = -1;
  String? _setupError;
  List<Order> _eligibleOrders = [];
  int _confirmedCount = 0;
  int _confirmFailedCount = 0;

  @override
  void initState() {
    super.initState();
    _statuses.addAll(List.filled(widget.orders.length, _RowStatus.waiting));
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAll());
  }

  Future<void> _checkAll() async {
    final settings = await resolveZrSettings(ref);
    if (settings == null || !settings.isConfigured) {
      setState(() => _setupError =
          'ZR Express is not configured yet — set it up in ZR Settings.');
      return;
    }

    final zrClient = ref.read(zrClientProvider);
    final eligible = <Order>[];

    for (var i = 0; i < widget.orders.length; i++) {
      final order = widget.orders[i];
      setState(() {
        _currentIndex = i;
        _statuses[i] = _RowStatus.checking;
      });
      try {
        final delivered = await zrClient.isParcelDelivered(
            order.zrParcelId!, settings.secretKey, settings.tenantId);
        setState(() => _statuses[i] =
            delivered ? _RowStatus.eligible : _RowStatus.notEligible);
        if (delivered) eligible.add(order);
      } catch (e) {
        debugPrint(
            'Multi-CP: fetch failed for order ${order.id} (parcel ${order.zrParcelId}): $e');
        setState(() => _statuses[i] = _RowStatus.failed);
      }
    }

    if (!mounted) return;
    setState(() {
      _eligibleOrders = eligible;
      _phase = _Phase.review;
    });
  }

  Future<void> _confirmAll() async {
    setState(() {
      _phase = _Phase.confirming;
      _currentIndex = -1;
    });

    for (var i = 0; i < _eligibleOrders.length; i++) {
      final order = _eligibleOrders[i];
      setState(() => _currentIndex = i);
      try {
        await widget.service.confirmPayment(order);
        setState(() => _confirmedCount++);
      } catch (e) {
        debugPrint('Multi-CP: confirmPayment failed for order ${order.id}: $e');
        setState(() => _confirmFailedCount++);
      }
    }

    if (!mounted) return;
    setState(() => _phase = _Phase.done);
  }

  void _finish() {
    final checked = widget.orders.length;
    final failedFetches =
        _statuses.where((s) => s == _RowStatus.failed).length;
    Navigator.of(context).pop(MultiCpResult(
      checked: checked,
      eligible: _eligibleOrders.length,
      confirmed: _confirmedCount,
      failed: _confirmFailedCount + failedFetches,
    ));
  }

  Widget _statusIcon(_RowStatus status) {
    switch (status) {
      case _RowStatus.waiting:
        return const Icon(Icons.remove, size: 16, color: AppColors.textHint);
      case _RowStatus.checking:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _RowStatus.eligible:
      case _RowStatus.confirmed:
        return const Icon(Icons.check_circle,
            size: 16, color: AppColors.success);
      case _RowStatus.notEligible:
        return const Icon(Icons.remove_circle_outline,
            size: 16, color: AppColors.textHint);
      case _RowStatus.failed:
        return const Icon(Icons.cancel, size: 16, color: AppColors.error);
    }
  }

  Widget _buildBody() {
    if (_setupError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            Text(
              _setupError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    switch (_phase) {
      case _Phase.checking:
        final total = widget.orders.length;
        final inProgress = _currentIndex >= 0 && _currentIndex < total;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              inProgress
                  ? 'Checking order ${_currentIndex + 1} of $total…'
                  : 'Preparing $total order(s)…',
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _ordersList(widget.orders, _statuses),
          ],
        );

      case _Phase.review:
        if (_eligibleOrders.isEmpty) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.textHint, size: 40),
              const SizedBox(height: 12),
              const Text(
                'No orders are marked as delivered by ZR Express yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Close'),
              ),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_eligibleOrders.length} of ${widget.orders.length} order(s) are '
              'delivered and ready for payment confirmation:',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _eligibleOrders.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.cardBorder),
                itemBuilder: (context, i) {
                  final order = _eligibleOrders[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            size: 16, color: AppColors.success),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${order.customerName} · #${order.id.substring(0, 8).toUpperCase()}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirmAll,
                    child:
                        Text('Confirm Payment (${_eligibleOrders.length})'),
                  ),
                ),
              ],
            ),
          ],
        );

      case _Phase.confirming:
        final total = _eligibleOrders.length;
        final inProgress = _currentIndex >= 0 && _currentIndex < total;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              inProgress
                  ? 'Confirming payment ${_currentIndex + 1} of $total…'
                  : 'Confirming $total order(s)…',
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _ordersList(
              _eligibleOrders,
              List.generate(_eligibleOrders.length, (i) {
                if (i < _currentIndex) return _RowStatus.confirmed;
                if (i == _currentIndex) return _RowStatus.checking;
                return _RowStatus.waiting;
              }),
            ),
          ],
        );

      case _Phase.done:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                color: AppColors.success, size: 40),
            const SizedBox(height: 12),
            Text(
              _confirmFailedCount > 0
                  ? 'Confirmed $_confirmedCount order(s). $_confirmFailedCount failed.'
                  : 'Confirmed $_confirmedCount order(s) successfully.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _finish,
              child: const Text('Done'),
            ),
          ],
        );
    }
  }

  Widget _ordersList(List<Order> orders, List<_RowStatus> statuses) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: orders.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.cardBorder),
        itemBuilder: (context, i) {
          final order = orders[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                _statusIcon(statuses[i]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${order.customerName} · #${order.id.substring(0, 8).toUpperCase()}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    'Multi-CP · Confirm Payment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  _buildBody(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
