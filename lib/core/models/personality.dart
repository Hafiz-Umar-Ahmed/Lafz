import 'package:lafz/core/enums/enums.dart';

class PersonalityModel {
  final int id;
  final String name;
  final String? description;
  final int categoryId;
  final String? imagePath;
  final PublicationStatus publicationStatus;
  final ContentTier tier;

  const PersonalityModel({
    required this.id,
    required this.name,
    this.description,
    required this.categoryId,
    this.imagePath,
    this.publicationStatus = PublicationStatus.published,
    this.tier = ContentTier.free,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category_id': categoryId,
      'image_path': imagePath,
      'publication_status': publicationStatus.name,
      'tier': tier.name,
    };
  }

  factory PersonalityModel.fromMap(Map<String, dynamic> map) {
    return PersonalityModel(
      id: map['id'] as int,
      name: map['name'] as String,
      description: map['description'] as String?,
      categoryId: map['category_id'] as int,
      imagePath: map['image_path'] as String?,
      publicationStatus: PublicationStatus.fromString(
        map['publication_status'] as String? ?? 'published',
      ),
      tier: ContentTier.fromString(map['tier'] as String? ?? 'free'),
    );
  }
}
