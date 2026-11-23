import 'package:lafz/core/enums/enums.dart';

class BackgroundModel {
  final int id;
  final BackgroundType type;
  final String filePath; // Color hex or asset path
  final double focalX;
  final double focalY;
  final String license;
  final String? attribution;
  final ContentTier tier;

  const BackgroundModel({
    required this.id,
    required this.type,
    required this.filePath,
    this.focalX = 0.5,
    this.focalY = 0.5,
    this.license = 'Unsplash License / CC0',
    this.attribution,
    this.tier = ContentTier.free,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'file_path': filePath,
      'focal_x': focalX,
      'focal_y': focalY,
      'license': license,
      'attribution': attribution,
      'tier': tier.name,
    };
  }

  factory BackgroundModel.fromMap(Map<String, dynamic> map) {
    return BackgroundModel(
      id: map['id'] as int,
      type: BackgroundType.fromString(map['type'] as String? ?? 'solid'),
      filePath: map['file_path'] as String,
      focalX: (map['focal_x'] as num?)?.toDouble() ?? 0.5,
      focalY: (map['focal_y'] as num?)?.toDouble() ?? 0.5,
      license: (map['license'] as String?) ?? 'CC0 / Public Domain',
      attribution: map['attribution'] as String?,
      tier: ContentTier.fromString(map['tier'] as String? ?? 'free'),
    );
  }
}
