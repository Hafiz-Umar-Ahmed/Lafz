import 'package:sqflite/sqflite.dart';
import 'package:lafz/core/enums/enums.dart';
import 'package:lafz/core/models/quote.dart';
import 'package:lafz/core/models/user_collection.dart';
import 'package:lafz/data/database/database_helper.dart';

class FollowedCollectionItem {
  final int id;
  final int collectionId;
  final CollectionType type;
  final String name;

  const FollowedCollectionItem({
    required this.id,
    required this.collectionId,
    required this.type,
    required this.name,
  });
}

class CollectionsRepository {
  final DatabaseHelper _dbHelper;
  CollectionsRepository([DatabaseHelper? dbHelper])
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  // --- Followed Collections ---
  Future<List<FollowedCollectionItem>> getFollowedCollections() async {
    final db = await _db;
    final results = await db.query(
      'followed_collections',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at DESC',
    );

    final items = <FollowedCollectionItem>[];
    for (final r in results) {
      final id = r['id'] as int;
      final collId = r['collection_id'] as int;
      final type = CollectionType.fromString(r['collection_type'] as String);
      String name = 'Collection $collId';

      if (type == CollectionType.category || type == CollectionType.subcategory) {
        final cat = await db.query('categories', columns: ['name'], where: 'id = ?', whereArgs: [collId]);
        if (cat.isNotEmpty) name = cat.first['name'] as String;
      } else if (type == CollectionType.personality) {
        final p = await db.query('personalities', columns: ['name'], where: 'id = ?', whereArgs: [collId]);
        if (p.isNotEmpty) name = p.first['name'] as String;
      }

      items.add(FollowedCollectionItem(id: id, collectionId: collId, type: type, name: name));
    }
    return items;
  }

  Future<bool> isFollowing(int collectionId, CollectionType type) async {
    final db = await _db;
    final results = await db.query(
      'followed_collections',
      where: 'collection_id = ? AND collection_type = ? AND deleted_at IS NULL',
      whereArgs: [collectionId, type.name],
    );
    return results.isNotEmpty;
  }

  Future<void> followCollection(int collectionId, CollectionType type) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.insert('followed_collections', {
      'collection_id': collectionId,
      'collection_type': type.name,
      'created_at': now,
    });

    // Also auto-enable for both surfaces by default
    for (final surface in ['widget', 'wallpaper']) {
      await db.insert('surface_collections', {
        'surface': surface,
        'collection_id': collectionId,
        'collection_type': type.name,
        'enabled': 1,
      });
    }
  }

  Future<void> unfollowCollection(int collectionId, CollectionType type) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'followed_collections',
      {'deleted_at': now, 'updated_at': now},
      where: 'collection_id = ? AND collection_type = ?',
      whereArgs: [collectionId, type.name],
    );

    // Disable in surface collections
    await db.delete(
      'surface_collections',
      where: 'collection_id = ? AND collection_type = ?',
      whereArgs: [collectionId, type.name],
    );
  }

  // --- Surface Collections (FR-006) ---
  Future<List<Map<String, dynamic>>> getSurfaceCollections(SurfaceType surface) async {
    final db = await _db;
    return await db.query(
      'surface_collections',
      where: 'surface = ?',
      whereArgs: [surface.name],
    );
  }

  Future<void> setSurfaceCollectionEnabled({
    required SurfaceType surface,
    required int collectionId,
    required CollectionType type,
    required bool enabled,
  }) async {
    final db = await _db;
    final count = await db.update(
      'surface_collections',
      {'enabled': enabled ? 1 : 0},
      where: 'surface = ? AND collection_id = ? AND collection_type = ?',
      whereArgs: [surface.name, collectionId, type.name],
    );
    if (count == 0) {
      await db.insert('surface_collections', {
        'surface': surface.name,
        'collection_id': collectionId,
        'collection_type': type.name,
        'enabled': enabled ? 1 : 0,
      });
    }
  }

  // --- User Personal Collections (FR-009) ---
  Future<List<UserCollectionModel>> getUserCollections() async {
    final db = await _db;
    final results = await db.query(
      'user_collections',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at DESC',
    );

    final list = <UserCollectionModel>[];
    for (final r in results) {
      final id = r['id'] as int;
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM user_collection_items WHERE collection_id = ?',
        [id],
      );
      final count = (countResult.first['count'] as num?)?.toInt() ?? 0;
      list.add(UserCollectionModel.fromMap(r, quoteCount: count));
    }
    return list;
  }

  Future<int> createUserCollection(String name) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    return await db.insert('user_collections', {
      'name': name.trim(),
      'created_at': now,
    });
  }

  Future<void> renameUserCollection(int id, String newName) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'user_collections',
      {'name': newName.trim(), 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteUserCollection(int id) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'user_collections',
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> addQuoteToCollection(int collectionId, int quoteId) async {
    final db = await _db;
    final existing = await db.query(
      'user_collection_items',
      where: 'collection_id = ? AND quote_id = ?',
      whereArgs: [collectionId, quoteId],
    );
    if (existing.isEmpty) {
      await db.insert('user_collection_items', {
        'collection_id': collectionId,
        'quote_id': quoteId,
      });
    }
  }

  Future<void> removeQuoteFromCollection(int collectionId, int quoteId) async {
    final db = await _db;
    await db.delete(
      'user_collection_items',
      where: 'collection_id = ? AND quote_id = ?',
      whereArgs: [collectionId, quoteId],
    );
  }

  Future<List<QuoteModel>> getCollectionQuotes(int collectionId) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT q.* FROM quotes q
      INNER JOIN user_collection_items uci ON q.id = uci.quote_id
      WHERE uci.collection_id = ?
      ORDER BY uci.sort_order ASC, uci.id ASC
    ''', [collectionId]);
    return results.map((r) => QuoteModel.fromMap(r)).toList();
  }

  // --- User Personal Quotes (FR-010) ---
  Future<List<UserQuoteModel>> getUserQuotes() async {
    final db = await _db;
    final results = await db.query(
      'user_quotes',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at DESC',
    );
    return results.map((r) => UserQuoteModel.fromMap(r)).toList();
  }

  Future<int> createUserQuote({required String text, String? attribution, String? notes}) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    return await db.insert('user_quotes', {
      'text': text.trim(),
      'attribution': attribution?.trim(),
      'notes': notes?.trim(),
      'created_at': now,
    });
  }

  Future<void> deleteUserQuote(int id) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'user_quotes',
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
