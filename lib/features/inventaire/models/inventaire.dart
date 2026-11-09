import 'package:cloud_firestore/cloud_firestore.dart';

enum InventaireStatus { draft, finalized }

/// A periodic stock-take session: resolves open orders/purchases to a
/// terminal status, then records a physical count of every active
/// product, valuing the result at cost price. `periodStart` is the
/// previous session's finalized `periodEnd` (null only for the very first
/// session ever run). `periodEnd` stays editable while [status] is
/// [InventaireStatus.draft]; everything is locked once finalized.
class Inventaire {
  const Inventaire({
    required this.id,
    this.periodStart,
    required this.periodEnd,
    required this.status,
    required this.createdAt,
    this.createdBy,
    this.finalizedAt,
    this.totalStockValuation = 0.0,
    this.totalOrdersResolved = 0,
    this.totalPurchasesResolved = 0,
    this.totalOrderPaymentsSettled = 0,
    this.totalPurchasePaymentsSettled = 0,
  });

  final String id;
  final DateTime? periodStart;
  final DateTime periodEnd;
  final InventaireStatus status;
  final DateTime createdAt;
  final String? createdBy;
  final DateTime? finalizedAt;
  final double totalStockValuation;
  final int totalOrdersResolved;
  final int totalPurchasesResolved;
  final int totalOrderPaymentsSettled;
  final int totalPurchasePaymentsSettled;

  bool get isDraft => status == InventaireStatus.draft;

  Map<String, dynamic> toMap() => {
        'periodStart':
            periodStart != null ? Timestamp.fromDate(periodStart!) : null,
        'periodEnd': Timestamp.fromDate(periodEnd),
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
        'createdBy': createdBy,
        'finalizedAt':
            finalizedAt != null ? Timestamp.fromDate(finalizedAt!) : null,
        'totalStockValuation': totalStockValuation,
        'totalOrdersResolved': totalOrdersResolved,
        'totalPurchasesResolved': totalPurchasesResolved,
        'totalOrderPaymentsSettled': totalOrderPaymentsSettled,
        'totalPurchasePaymentsSettled': totalPurchasePaymentsSettled,
      };

  factory Inventaire.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return Inventaire(
      id: doc.id,
      periodStart: (m['periodStart'] as Timestamp?)?.toDate(),
      periodEnd: (m['periodEnd'] as Timestamp).toDate(),
      status: InventaireStatus.values.firstWhere(
        (s) => s.name == m['status'],
        orElse: () => InventaireStatus.draft,
      ),
      createdAt: (m['createdAt'] as Timestamp).toDate(),
      createdBy: m['createdBy'] as String?,
      finalizedAt: (m['finalizedAt'] as Timestamp?)?.toDate(),
      totalStockValuation:
          (m['totalStockValuation'] as num? ?? 0.0).toDouble(),
      totalOrdersResolved: m['totalOrdersResolved'] as int? ?? 0,
      totalPurchasesResolved: m['totalPurchasesResolved'] as int? ?? 0,
      totalOrderPaymentsSettled: m['totalOrderPaymentsSettled'] as int? ?? 0,
      totalPurchasePaymentsSettled:
          m['totalPurchasePaymentsSettled'] as int? ?? 0,
    );
  }
}
