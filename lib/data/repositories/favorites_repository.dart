import 'package:sqflite/sqflite.dart';
import 'package:lafz/core/models/quote.dart';
import 'package:lafz/data/database/database_helper.dart';

class FavoritesRepository {
  final DatabaseHelper _dbHelper;
  FavoritesRepository([DatabaseHelper? dbHelper])
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  Future<List<QuoteModel>> getFavorites() async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT q.* FROM quotes q
      INNER JOIN favorites f ON q.id = f.quote_id
      WHERE f.deleted_at IS NULL
      ORDER BY f.created_at DESC
    ''');
    return results.map((r) => QuoteModel.fromMap(r)).toList();
  }

  Future<bool> isFavorite(int quoteId) async {
    final db = await _db;
    final results = await db.query(
      'favorites',
      where: 'quote_id = ? AND deleted_at IS NULL',
      whereArgs: [quoteId],
    );
    return results.isNotEmpty;
  }

  Future<void> addFavorite(int quoteId) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      'favorites',
      where: 'quote_id = ?',
      whereArgs: [quoteId],
    );
    if (existing.isNotEmpty) {
      await db.update(
        'favorites',
        {'deleted_at': null, 'updated_at': now},
        where: 'quote_id = ?',
        whereArgs: [quoteId],
      );
    } else {
      await db.insert(
        'favorites',
        {
          'quote_id': quoteId,
          'created_at': now,
          'updated_at': now,
          'deleted_at': null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> removeFavorite(int quoteId) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'favorites',
      {'deleted_at': now, 'updated_at': now},
      where: 'quote_id = ?',
      whereArgs: [quoteId],
    );
  }

  Future<bool> toggleFavorite(int quoteId) async {
    final fav = await isFavorite(quoteId);
    if (fav) {
      await removeFavorite(quoteId);
      return false;
    } else {
      await addFavorite(quoteId);
      return true;
    }
  }

  Future<List<int>> getFavoriteQuoteIds() async {
    final db = await _db;
    final results = await db.query(
      'favorites',
      columns: ['quote_id'],
      where: 'deleted_at IS NULL',
    );
    return results.map((r) => r['quote_id'] as int).toList();
  }
}
