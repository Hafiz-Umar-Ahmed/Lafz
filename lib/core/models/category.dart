import 'package:lafz/core/enums/enums.dart';

class CategoryModel {
  final int id;
  final String name;
  final int? parentId;
  final String? description;
  final int sortOrder;
  final PublicationStatus publicationStatus;
  final ContentTier tier;

  const CategoryModel({
    required this.id,
    required this.name,
    this.parentId,
    this.description,
    this.sortOrder = 0,
    this.publicationStatus = PublicationStatus.published,
    this.tier = ContentTier.free,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'description': description,
      'sort_order': sortOrder,
      'publication_status': publicationStatus.name,
      'tier': tier.name,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int,
      name: map['name'] as String,
      parentId: map['parent_id'] as int?,
      description: map['description'] as String?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      publicationStatus: PublicationStatus.fromString(
        map['publication_status'] as String? ?? 'published',
      ),
      tier: ContentTier.fromString(map['tier'] as String? ?? 'free'),
    );
  }
}
