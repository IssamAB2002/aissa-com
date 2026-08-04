import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../orders/models/order.dart';
import '../models/hub.dart';

class ZrServiceException implements Exception {
  ZrServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

const _zrBaseUrl = 'https://api.zrexpress.app/api/v1';

/// ZR Express API client — ports Modeline's `zr_service.py` logic 1:1 for
/// direct client-side calls (this app has no backend to route through).
class ZrClient {
  ZrClient(this._db);

  final FirebaseFirestore _db;
  CollectionReference get _ordersCol => _db.collection('orders');
  CollectionReference get _hubsCol => _db.collection('zr_hubs');

  static String formatPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^0[567]\d{8}$').hasMatch(digits)) {
      throw ZrServiceException(
        'Invalid phone number "$raw" — must start with 05, 06, or 07 and '
        'have 10 digits.',
      );
    }
    return '+213${digits.substring(1)}';
  }

  Future<dynamic> _request(
    String url,
    String method,
    String secretKey,
    String tenantId, {
    Map<String, dynamic>? body,
  }) async {
    final headers = {
      'X-Api-Key': secretKey,
      'X-Tenant': tenantId,
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };
    final uri = Uri.parse(url);
    if (body != null) {
      debugPrint('ZR $method $url body: ${jsonEncode(body)}');
    }
    final http.Response response;
    switch (method) {
      case 'POST':
        response = await http.post(uri,
            headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      default:
        throw ArgumentError('Unsupported method: $method');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final snippet = response.body.length > 300
          ? response.body.substring(0, 300)
          : response.body;
      throw ZrServiceException('ZR HTTP ${response.statusCode}: $snippet');
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  Future<Hub?> _fetchHub(String hubId) async {
    final doc = await _hubsCol.doc(hubId).get();
    if (!doc.exists) return null;
    return Hub.fromDoc(doc);
  }

  bool _isHome(Order order) => order.deliveryType == DeliveryType.homeDelivery;

  void _checkDeliveryRefs(Order order) {
    if (order.wilayaZrTerritoryId == null) {
      throw ZrServiceException(
        'This order has no ZR wilaya territory id — sync territories in ZR Settings first.',
      );
    }
    if (_isHome(order)) {
      if (order.baladiaZrTerritoryId == null) {
        throw ZrServiceException(
          'Home delivery requires a baladia with a ZR territory id.',
        );
      }
    } else if (order.hubZrId == null) {
      throw ZrServiceException(
        'Pickup-point delivery requires a selected ZR hub.',
      );
    }
  }

  Future<Map<String, dynamic>> _buildCustomerPayload(Order order) async {
    _checkDeliveryRefs(order);
    final isHome = _isHome(order);

    final address = <String, dynamic>{
      'city': order.wilayaName,
      'cityTerritoryId': order.wilayaZrTerritoryId,
      'country': 'algeria',
      'isPrimary': true,
    };

    if (isHome) {
      if (order.address != null) address['street'] = order.address;
      address['district'] = order.baladiaName;
      address['districtTerritoryId'] = order.baladiaZrTerritoryId;
    } else {
      final hub = await _fetchHub(order.hubId!);
      address['district'] =
          (hub != null && hub.district.isNotEmpty) ? hub.district : order.hubName;
      if (hub != null && hub.street.isNotEmpty) address['street'] = hub.street;
    }

    return {
      'name': order.customerName,
      'phone': {'number1': formatPhone(order.customerPhone ?? '')},
      'timeSlot': 'morning',
      'instruction': '',
      'deliveryPreference': isHome ? 'home' : 'pickup-point',
      'addresses': [address],
    };
  }

  /// Reuses `order.zrCustomerId` if already set; otherwise dedupes against a
  /// prior order from the same phone number, else creates a new ZR customer.
  Future<String> getOrCreateCustomerId(
    Order order,
    String secretKey,
    String tenantId,
  ) async {
    if (order.zrCustomerId != null) return order.zrCustomerId!;

    if (order.customerPhone != null) {
      final snap = await _ordersCol
          .where('customerPhone', isEqualTo: order.customerPhone)
          .get();
      final siblings = snap.docs
          .where((d) =>
              d.id != order.id &&
              (d.data() as Map<String, dynamic>)['zrCustomerId'] != null)
          .toList()
        ..sort((a, b) {
          final ta = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final tb = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          return (tb ?? Timestamp(0, 0)).compareTo(ta ?? Timestamp(0, 0));
        });
      if (siblings.isNotEmpty) {
        final zrCustomerId =
            (siblings.first.data() as Map<String, dynamic>)['zrCustomerId']
                as String;
        await _ordersCol.doc(order.id).update({'zrCustomerId': zrCustomerId});
        return zrCustomerId;
      }
    }

    final payload = await _buildCustomerPayload(order);
    final response = await _request(
      '$_zrBaseUrl/customers/individual',
      'POST',
      secretKey,
      tenantId,
      body: payload,
    ) as Map<String, dynamic>?;

    final customerId = response?['id'] as String?;
    if (customerId == null) {
      throw ZrServiceException(
          'ZR response missing customer id: ${response ?? '(empty)'}');
    }
    await _ordersCol.doc(order.id).update({'zrCustomerId': customerId});
    return customerId;
  }

  Future<Map<String, dynamic>> buildParcelPayload(
    Order order,
    String customerId,
  ) async {
    _checkDeliveryRefs(order);
    final isHome = _isHome(order);

    final deliveryAddress = <String, dynamic>{
      'cityTerritoryId': order.wilayaZrTerritoryId,
      'city': order.wilayaName,
    };
    if (isHome) {
      deliveryAddress['districtTerritoryId'] = order.baladiaZrTerritoryId;
      deliveryAddress['district'] = order.baladiaName;
      if (order.address != null && order.address!.isNotEmpty) {
        deliveryAddress['street'] = order.address;
      }
    } else {
      deliveryAddress['hubId'] = order.hubZrId;
      deliveryAddress['hubName'] = order.hubName;
    }

    final orderedProducts = order.items
        .map((item) => {
              'productName': item.productName,
              'unitPrice': item.unitPrice.round(),
              'quantity': item.quantity,
              'stockType': 'none',
            })
        .toList();

    final description = (order.notes != null && order.notes!.isNotEmpty)
        ? order.notes!
        : order.items.map((i) => '${i.quantity}x ${i.productName}').join(', ');

    final payload = <String, dynamic>{
      'customer': {
        'customerId': customerId,
        'name': order.customerName,
        'phone': {'number1': formatPhone(order.customerPhone ?? '')},
      },
      'deliveryAddress': deliveryAddress,
      'deliveryType': isHome ? 'home' : 'pickup-point',
      'amount': (order.total + order.fees).round(),
      'description':
          description.length > 500 ? description.substring(0, 500) : description,
      'orderedProducts': orderedProducts,
    };

    if (!isHome) {
      final hub = await _fetchHub(order.hubId!);
      payload['hubId'] = order.hubZrId;
      final stopdeskAddress = [hub?.street, order.wilayaName]
          .where((s) => s != null && s.isNotEmpty)
          .join(', ');
      payload['pickupPoint'] = {
        'stopdesk_id': order.hubZrId,
        'stopdesk_name': order.hubName,
        'stopdesk_cityTerritoryId': order.wilayaZrTerritoryId,
        'stopdesk_address': stopdeskAddress,
        'stopdesk_phone': hub?.phone ?? '',
      };
    }

    return payload;
  }

  /// Posts [order] as a parcel to ZR Express. Returns the ZR parcel id,
  /// tracking number, and customer id — the caller persists these onto the
  /// order doc.
  Future<({String parcelId, String trackingNumber, String customerId})>
      postParcel(Order order, String secretKey, String tenantId) async {
    if (order.zrSubmitted || order.zrParcelId != null) {
      throw ZrServiceException(
        'Order already submitted to ZR Express (parcel: ${order.zrParcelId}).',
      );
    }

    final customerId = await getOrCreateCustomerId(order, secretKey, tenantId);
    final payload = await buildParcelPayload(order, customerId);
    final response = await _request(
      '$_zrBaseUrl/parcels',
      'POST',
      secretKey,
      tenantId,
      body: payload,
    ) as Map<String, dynamic>?;

    final parcelId = response?['id'] as String?;
    final trackingNumber = response?['trackingNumber'] as String? ?? '';
    if (parcelId == null) {
      throw ZrServiceException(
          'ZR response missing parcel id: ${response ?? '(empty)'}');
    }

    return (
      parcelId: parcelId,
      trackingNumber: trackingNumber,
      customerId: customerId,
    );
  }

  Future<void> deleteParcel(
      Order order, String secretKey, String tenantId) async {
    if (order.zrParcelId == null) {
      throw ZrServiceException('Order has no ZR parcel id to delete.');
    }
    await _request(
      '$_zrBaseUrl/parcels/${order.zrParcelId}',
      'DELETE',
      secretKey,
      tenantId,
    );
  }
}
