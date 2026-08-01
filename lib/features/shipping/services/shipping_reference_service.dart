import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../models/baladia.dart';
import '../models/hub.dart';
import '../models/wilaya.dart';
import '../models/zr_settings.dart';

const _territoriesSearchUrl =
    'https://api.zrexpress.app/api/v1.0/territories/search';
const _hubsSearchUrl = 'https://api.zrexpress.app/api/v1/hubs/search';

class ShippingReferenceService {
  ShippingReferenceService(this._db);

  final FirebaseFirestore _db;
  CollectionReference get _wilayasCol => _db.collection('wilayas');
  CollectionReference get _baladiasCol => _db.collection('baladias');
  CollectionReference get _hubsCol => _db.collection('zr_hubs');
  DocumentReference get _settingsDoc =>
      _db.collection('settings').doc('zrExpress');

  Stream<List<Wilaya>> streamWilayas() => _wilayasCol
      .orderBy('code')
      .snapshots()
      .map((s) => s.docs.map(Wilaya.fromDoc).toList());

  Stream<List<Baladia>> streamBaladias(String? wilayaId) {
    if (wilayaId == null) return Stream.value(const []);
    return _baladiasCol.where('wilayaId', isEqualTo: wilayaId).snapshots().map(
      (s) {
        final list = s.docs.map(Baladia.fromDoc).toList();
        list.sort((a, b) => a.nameFr.compareTo(b.nameFr));
        return list;
      },
    );
  }

  Stream<List<Hub>> streamHubs(String? wilayaId) {
    if (wilayaId == null) return Stream.value(const []);
    return _hubsCol.where('wilayaId', isEqualTo: wilayaId).snapshots().map(
      (s) {
        final list = s.docs
            .map(Hub.fromDoc)
            .where((h) => h.isPickupPoint && h.isVisible)
            .toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      },
    );
  }

  Stream<ZrSettings> streamZrSettings() => _settingsDoc.snapshots().map((doc) {
        if (!doc.exists) return const ZrSettings();
        return ZrSettings.fromMap(doc.data() as Map<String, dynamic>);
      });

  Future<void> saveZrSettings(ZrSettings settings) =>
      _settingsDoc.set(settings.toMap(), SetOptions(merge: true));

  Map<String, String> _headers(String secretKey, String tenantId) => {
        'X-Api-Key': secretKey,
        'X-Tenant': tenantId,
        'Content-Type': 'application/json',
      };

  Future<List<Map<String, dynamic>>> _fetchAllPages(
    String url,
    String secretKey,
    String tenantId,
  ) async {
    final items = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final response = await http.post(
        Uri.parse(url),
        headers: _headers(secretKey, tenantId),
        body: jsonEncode({'pageNumber': page, 'pageSize': 1000}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'ZR request failed (${response.statusCode}): ${response.body}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final pageItems = (data['items'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      items.addAll(pageItems);
      final totalPages = (data['totalPages'] as num? ?? 1).toInt();
      if (page >= totalPages) break;
      page++;
    }
    return items;
  }

  Future<void> _commitInChunks(
      List<void Function(WriteBatch batch)> writes) async {
    const chunkSize = 450;
    for (var i = 0; i < writes.length; i += chunkSize) {
      final batch = _db.batch();
      for (final write
          in writes.skip(i).take(chunkSize)) {
        write(batch);
      }
      await batch.commit();
    }
  }

  /// Syncs wilaya + baladia (commune) territories from ZR Express, upserting
  /// by ZR's territory UUID (used directly as the Firestore document id).
  Future<({int wilayas, int baladias})> syncTerritoriesFromZr(
    String secretKey,
    String tenantId,
  ) async {
    final items = await _fetchAllPages(
        _territoriesSearchUrl, secretKey, tenantId);

    final wilayaItems = items.where((t) => t['level'] == 'wilaya').toList();
    final communeItems = items.where((t) => t['level'] == 'commune').toList();

    final writes = <void Function(WriteBatch batch)>[];

    for (final t in wilayaItems) {
      final zrId = t['id'] as String?;
      final code = t['code'];
      if (zrId == null || code is! num) continue;
      writes.add((batch) => batch.set(
            _wilayasCol.doc(zrId),
            {
              'code': code.toInt(),
              'nameAr': (t['nameArabic'] as String? ?? '').trim(),
              'nameFr': (t['name'] as String? ?? '').trim(),
              'zrTerritoryId': zrId,
            },
            SetOptions(merge: true),
          ));
    }

    for (final t in communeItems) {
      final zrId = t['id'] as String?;
      final parentId = t['parentId'] as String?;
      if (zrId == null || parentId == null) continue;
      writes.add((batch) => batch.set(
            _baladiasCol.doc(zrId),
            {
              'wilayaId': parentId,
              'nameAr': (t['nameArabic'] as String? ?? '').trim(),
              'nameFr': (t['name'] as String? ?? '').trim(),
              'zrTerritoryId': zrId,
            },
            SetOptions(merge: true),
          ));
    }

    await _commitInChunks(writes);
    return (wilayas: wilayaItems.length, baladias: communeItems.length);
  }

  /// Syncs hubs (pickup points/stopdesks) from ZR Express, upserting by ZR's
  /// hub UUID (used directly as the Firestore document id).
  Future<int> syncHubsFromZr(String secretKey, String tenantId) async {
    final items = await _fetchAllPages(_hubsSearchUrl, secretKey, tenantId);

    final writes = <void Function(WriteBatch batch)>[];
    for (final item in items) {
      final zrId = item['id'] as String?;
      if (zrId == null) continue;
      final address = item['address'] as Map<String, dynamic>? ?? {};
      final coordinates =
          address['coordinates'] as Map<String, dynamic>? ?? {};
      final phone = item['phone'] as Map<String, dynamic>? ?? {};

      writes.add((batch) => batch.set(
            _hubsCol.doc(zrId),
            {
              'zrHubId': zrId,
              'name': item['name'] as String? ?? '',
              'type': item['type'] as String? ?? 'hub',
              'isPickupPoint': item['isPickupPoint'] as bool? ?? false,
              'isVisible': item['isVisible'] as bool? ?? false,
              'wilayaId': address['cityTerritoryId'] as String?,
              'street': address['street'] as String? ?? '',
              'district': address['district'] as String? ?? '',
              'postalCode': address['postalCode'] as String? ?? '',
              'phone': phone['number1'] as String? ?? '',
              'lat': (coordinates['lat'] as num?)?.toDouble(),
              'lng': (coordinates['lng'] as num?)?.toDouble(),
            },
          ));
    }

    await _commitInChunks(writes);
    return items.length;
  }
}
