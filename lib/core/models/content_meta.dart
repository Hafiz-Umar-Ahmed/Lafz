class ContentMetaModel {
  final int installedVersion;
  final String? checksum;
  final DateTime installedAt;

  const ContentMetaModel({
    required this.installedVersion,
    this.checksum,
    required this.installedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'installed_version': installedVersion,
      'checksum': checksum,
      'installed_at': installedAt.toIso8601String(),
    };
  }

  factory ContentMetaModel.fromMap(Map<String, dynamic> map) {
    return ContentMetaModel(
      installedVersion: (map['installed_version'] as int?) ?? 1,
      checksum: map['checksum'] as String?,
      installedAt: DateTime.tryParse(map['installed_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
