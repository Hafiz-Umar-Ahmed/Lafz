import 'package:sqflite/sqflite.dart';
import 'package:lafz/core/enums/enums.dart';
import 'package:lafz/core/models/quote.dart';
import 'package:lafz/data/database/database_helper.dart';

class QuotesRepository {
  final DatabaseHelper _dbHelper;
  QuotesRepository([DatabaseHelper? dbHelper])
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  Future<QuoteModel?> getQuoteById(int id) async {
    final db = await _db;
    final results = await db.query(
      'quotes',
      where: 'id = ? AND publication_status = ?',
      whereArgs: [id, 'published'],
    );
    if (results.isEmpty) return null;

    final catResults = await db.query(
      'quote_categories',
      columns: ['category_id'],
      where: 'quote_id = ?',
      whereArgs: [id],
    );
    final catIds = catResults.map((r) => r['category_id'] as int).toList();

    return QuoteModel.fromMap(results.first, categories: catIds);
  }

  Future<List<QuoteModel>> getQuotesByPersonality(int personalityId) async {
    final db = await _db;
    final results = await db.query(
      'quotes',
      where: 'personality_id = ? AND publication_status = ? AND verification_status IN (?, ?)',
      whereArgs: [personalityId, 'published', 'verified', 'verifiedTranslation'],
      orderBy: 'id ASC',
    );
    return results.map((r) => QuoteModel.fromMap(r)).toList();
  }

  Future<List<QuoteModel>> getQuotesByCategory(int categoryId) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT q.* FROM quotes q
      INNER JOIN quote_categories qc ON q.id = qc.quote_id
      WHERE qc.category_id = ? 
        AND q.publication_status = 'published'
        AND q.verification_status IN ('verified', 'verifiedTranslation')
      ORDER BY q.id ASC
    ''', [categoryId]);

    return results.map((r) => QuoteModel.fromMap(r)).toList();
  }

  Future<List<QuoteModel>> searchQuotes(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final db = await _db;
    try {
      // First try FTS5 query
      final ftsResults = await db.rawQuery('''
        SELECT q.* FROM quotes q
        INNER JOIN quotes_fts fts ON q.id = fts.quote_id
        WHERE quotes_fts MATCH ?
          AND q.publication_status = 'published'
          AND q.verification_status IN ('verified', 'verifiedTranslation')
        LIMIT 50
      ''', ['"$cleanQuery"*']);

      if (ftsResults.isNotEmpty) {
        return ftsResults.map((r) => QuoteModel.fromMap(r)).toList();
      }
    } catch (_) {
      // Fallback to LIKE if FTS fails
    }

    final likePattern = '%$cleanQuery%';
    final results = await db.query(
      'quotes',
      where: '''
        publication_status = 'published'
        AND verification_status IN ('verified', 'verifiedTranslation')
        AND (text LIKE ? OR attribution LIKE ? OR source_title LIKE ?)
      ''',
      whereArgs: [likePattern, likePattern, likePattern],
      limit: 50,
    );

    return results.map((r) => QuoteModel.fromMap(r)).toList();
  }

  Future<List<int>> getEligibleQuoteIds({
    required List<int> categoryIds,
    required List<int> personalityIds,
    required bool includeFavorites,
    ContentTier? tier,
  }) async {
    final db = await _db;
    final Set<int> ids = {};
    final tierClause = tier == ContentTier.free ? " AND tier = 'free'" : "";

    if (personalityIds.isNotEmpty) {
      final placeholders = List.filled(personalityIds.length, '?').join(',');
      final pResults = await db.rawQuery('''
        SELECT id FROM quotes
        WHERE personality_id IN ($placeholders)
          AND publication_status = 'published'$tierClause
      ''', personalityIds);
      for (final r in pResults) {
        ids.add(r['id'] as int);
      }
    }

    if (categoryIds.isNotEmpty) {
      final placeholders = List.filled(categoryIds.length, '?').join(',');
      final cResults = await db.rawQuery('''
        SELECT DISTINCT q.id FROM quotes q
        INNER JOIN quote_categories qc ON q.id = qc.quote_id
        WHERE qc.category_id IN ($placeholders)
          AND q.publication_status = 'published'$tierClause
      ''', categoryIds);
      for (final r in cResults) {
        ids.add(r['id'] as int);
      }
    }

    if (includeFavorites) {
      final fResults = await db.rawQuery('''
        SELECT quote_id FROM favorites WHERE deleted_at IS NULL
      ''');
      for (final r in fResults) {
        ids.add(r['quote_id'] as int);
      }
    }

    return ids.toList();
  }

  Future<QuoteModel?> getRandomQuote() async {
    final db = await _db;
    final results = await db.query(
      'quotes',
      where: "publication_status = 'published'",
      orderBy: 'RANDOM()',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return QuoteModel.fromMap(results.first);
  }

  Future<List<QuoteModel>> getAllPublishedQuotes({int limit = 100, ContentTier? tier}) async {
    final db = await _db;
    final where = tier == ContentTier.free
        ? "publication_status = 'published' AND tier = 'free'"
        : "publication_status = 'published'";
    final results = await db.query(
      'quotes',
      where: where,
      limit: limit,
      orderBy: 'id ASC',
    );
    return results.map((r) => QuoteModel.fromMap(r)).toList();
  }
}
