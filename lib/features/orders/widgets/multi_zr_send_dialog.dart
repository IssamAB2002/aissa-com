import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../shipping/models/wilaya.dart';
import '../../shipping/providers/shipping_reference_provider.dart';
import '../../shipping/services/zr_client.dart';
import '../models/order.dart';
import '../services/orders_service.dart';

enum _SendStatus { waiting, sending, success, failed, skipped }

class MultiZrSendResult {
  const MultiZrSendResult({
    required this.succeeded,
    required this.failed,
    this.errorMessage,
  });

  final int succeeded;
  final int failed;
  final String? errorMessage;
}

class MultiZrSendDialog extends ConsumerStatefulWidget {
  const MultiZrSendDialog({
    super.key,
    required this.orders,
    required this.service,
  });

  final List<Order> orders;
  final OrdersService service;

  static Future<MultiZrSendResult> show(
    BuildContext context, {
    required List<Order> orders,
    required OrdersService service,
  }) async {
    final result = await showDialog<MultiZrSendResult>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => MultiZrSendDialog(orders: orders, service: service),
    );
    return result ??
        const MultiZrSendResult(
          succeeded: 0,
          failed: 0,
          errorMessage: 'Cancelled',
        );
  }

  @override
  ConsumerState<MultiZrSendDialog> createState() => _MultiZrSendDialogState();
}

class _MultiZrSendDialogState extends ConsumerState<MultiZrSendDialog> {
  final List<_SendStatus> _statuses = [];
  int _currentIndex = -1;

  @override
  void initState() {
    super.initState();
    _statuses.addAll(List.filled(widget.orders.length, _SendStatus.waiting));
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final settings = ref.read(zrSettingsStreamProvider).valueOrNull;
    if (settings == null || !settings.isConfigured) {
      Navigator.of(context).pop(const MultiZrSendResult(
        succeeded: 0,
        failed: 0,
        errorMessage:
            'ZR Express is not configured yet — set it up in ZR Settings.',
      ));
      return;
    }

    final zrClient = ref.read(zrClientProvider);
    final wilayas = await ref.read(wilayasStreamProvider.future);
    var succeeded = 0;
    String? errorMessage;

    for (var i = 0; i < widget.orders.length; i++) {
      final order = widget.orders[i];
      setState(() {
        _currentIndex = i;
        _statuses[i] = _SendStatus.sending;
      });
      try {
        final result = await zrClient.postParcel(
            order, settings.secretKey, settings.tenantId);
        Wilaya? wilaya;
        for (final w in wilayas) {
          if (w.id == order.wilayaId) {
            wilaya = w;
            break;
          }
        }
        final zrDeliveryFee = order.deliveryType == DeliveryType.homeDelivery
            ? (wilaya?.shippingPriceHome ?? 0.0)
            : (wilaya?.shippingPriceDesk ?? 0.0);
        await widget.service.markZrPushed(
          order.id,
          zrParcelId: result.parcelId,
          zrTrackingNumber: result.trackingNumber,
          zrCustomerId: result.customerId,
          zrDeliveryFee: zrDeliveryFee,
        );
        setState(() {
          _statuses[i] = _SendStatus.success;
          succeeded++;
        });
      } catch (e) {
        errorMessage = e is ZrServiceException ? e.message : '$e';
        setState(() {
          _statuses[i] = _SendStatus.failed;
          for (var j = i + 1; j < widget.orders.length; j++) {
            _statuses[j] = _SendStatus.skipped;
          }
        });
        break;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(MultiZrSendResult(
      succeeded: succeeded,
      failed: errorMessage != null ? 1 : 0,
      errorMessage: errorMessage,
    ));
  }

  Widget _statusIcon(_SendStatus status) {
    switch (status) {
      case _SendStatus.waiting:
      case _SendStatus.skipped:
        return const Icon(Icons.remove, size: 16, color: AppColors.textHint);
      case _SendStatus.sending:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _SendStatus.success:
        return const Icon(Icons.check_circle,
            size: 16, color: AppColors.success);
      case _SendStatus.failed:
        return const Icon(Icons.cancel, size: 16, color: AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.orders.length;
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
                    child: const Icon(Icons.local_shipping_outlined,
                        color: AppColors.primary, size: 30),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Sending to ZR Express',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    inProgress
                        ? 'Sending order ${_currentIndex + 1} of $total…'
                        : 'Preparing $total order(s)…',
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
                        final order = widget.orders[i];
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              _statusIcon(_statuses[i]),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${order.customerName} · #${order.id.substring(0, 8).toUpperCase()}',
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
