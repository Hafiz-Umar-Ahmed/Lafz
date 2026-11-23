import 'package:sqflite/sqflite.dart';
import 'package:lafz/core/models/personality.dart';
import 'package:lafz/data/database/database_helper.dart';

class PersonalitiesRepository {
  final DatabaseHelper _dbHelper;
  PersonalitiesRepository([DatabaseHelper? dbHelper])
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  Future<List<PersonalityModel>> getPersonalitiesByCategory(int categoryId) async {
    final db = await _db;
    final results = await db.query(
      'personalities',
      where: "category_id = ? AND publication_status = 'published'",
      whereArgs: [categoryId],
      orderBy: 'id ASC',
    );
    return results.map((r) => PersonalityModel.fromMap(r)).toList();
  }

  Future<PersonalityModel?> getPersonalityById(int id) async {
    final db = await _db;
    final results = await db.query(
      'personalities',
      where: 'id = ? AND publication_status = ?',
      whereArgs: [id, 'published'],
    );
    if (results.isEmpty) return null;
    return PersonalityModel.fromMap(results.first);
  }

  Future<List<PersonalityModel>> getAllPublishedPersonalities() async {
    final db = await _db;
    final results = await db.query(
      'personalities',
      where: "publication_status = 'published'",
      orderBy: 'id ASC',
    );
    return results.map((r) => PersonalityModel.fromMap(r)).toList();
  }

  Future<List<PersonalityModel>> getFeaturedPersonalities() async {
    final db = await _db;
    final results = await db.query(
      'personalities',
      where: "publication_status = 'published'",
      limit: 8,
      orderBy: 'id ASC',
    );
    return results.map((r) => PersonalityModel.fromMap(r)).toList();
  }

  Future<List<PersonalityModel>> searchPersonalities(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final db = await _db;
    final results = await db.query(
      'personalities',
      where: "publication_status = 'published' AND (name LIKE ? OR description LIKE ?)",
      whereArgs: ['%$cleanQuery%', '%$cleanQuery%'],
      limit: 20,
    );
    return results.map((r) => PersonalityModel.fromMap(r)).toList();
  }
}
