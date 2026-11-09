import 'package:cloud_firestore/cloud_firestore.dart';

/// A record of an order or purchase that was force-resolved to a terminal
/// status during an Inventaire session's resolve step.
class InventaireResolution {
  const InventaireResolution({
    required this.refId,
    required this.label,
    required this.previousStatus,
    required this.newStatus,
  });

  final String refId;
  final String label;
  final String previousStatus;
  final String newStatus;

  Map<String, dynamic> toMap() => {
        'refId': refId,
        'label': label,
        'previousStatus': previousStatus,
        'newStatus': newStatus,
      };

  factory InventaireResolution.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return InventaireResolution(
      refId: m['refId'] as String,
      label: m['label'] as String,
      previousStatus: m['previousStatus'] as String,
      newStatus: m['newStatus'] as String,
    );
  }
}
