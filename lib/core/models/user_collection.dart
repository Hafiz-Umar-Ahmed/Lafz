class UserCollectionModel {
  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int quoteCount;

  const UserCollectionModel({
    required this.id,
    required this.name,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.quoteCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory UserCollectionModel.fromMap(Map<String, dynamic> map, {int quoteCount = 0}) {
    return UserCollectionModel(
      id: map['id'] as int,
      name: map['name'] as String,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
      deletedAt: map['deleted_at'] != null
          ? DateTime.tryParse(map['deleted_at'] as String)
          : null,
      quoteCount: quoteCount,
    );
  }
}

class UserQuoteModel {
  final int id;
  final String text;
  final String? attribution;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const UserQuoteModel({
    required this.id,
    required this.text,
    this.attribution,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'attribution': attribution,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory UserQuoteModel.fromMap(Map<String, dynamic> map) {
    return UserQuoteModel(
      id: map['id'] as int,
      text: map['text'] as String,
      attribution: map['attribution'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
      deletedAt: map['deleted_at'] != null
          ? DateTime.tryParse(map['deleted_at'] as String)
          : null,
    );
  }
}
