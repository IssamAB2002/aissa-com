class ZrSettings {
  const ZrSettings({this.secretKey = '', this.tenantId = ''});

  final String secretKey;
  final String tenantId;

  bool get isConfigured => secretKey.isNotEmpty && tenantId.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'secretKey': secretKey,
        'tenantId': tenantId,
      };

  factory ZrSettings.fromMap(Map<String, dynamic> m) => ZrSettings(
        secretKey: m['secretKey'] as String? ?? '',
        tenantId: m['tenantId'] as String? ?? '',
      );
}
