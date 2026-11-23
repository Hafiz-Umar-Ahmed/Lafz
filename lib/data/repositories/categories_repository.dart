import 'package:sqflite/sqflite.dart';
import 'package:lafz/core/models/category.dart';
import 'package:lafz/data/database/database_helper.dart';

class CategoriesRepository {
  final DatabaseHelper _dbHelper;
  CategoriesRepository([DatabaseHelper? dbHelper])
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  Future<List<CategoryModel>> getRootCategories() async {
    final db = await _db;
    final results = await db.query(
      'categories',
      where: "parent_id IS NULL AND publication_status = 'published'",
      orderBy: 'sort_order ASC, name ASC',
    );
    return results.map((r) => CategoryModel.fromMap(r)).toList();
  }

  Future<List<CategoryModel>> getSubcategories(int parentId) async {
    final db = await _db;
    final results = await db.query(
      'categories',
      where: "parent_id = ? AND publication_status = 'published'",
      whereArgs: [parentId],
      orderBy: 'sort_order ASC, name ASC',
    );
    return results.map((r) => CategoryModel.fromMap(r)).toList();
  }

  Future<CategoryModel?> getCategoryById(int id) async {
    final db = await _db;
    final results = await db.query(
      'categories',
      where: 'id = ? AND publication_status = ?',
      whereArgs: [id, 'published'],
    );
    if (results.isEmpty) return null;
    return CategoryModel.fromMap(results.first);
  }

  Future<List<CategoryModel>> getAllPublishedCategories() async {
    final db = await _db;
    final results = await db.query(
      'categories',
      where: "publication_status = 'published'",
      orderBy: 'sort_order ASC, name ASC',
    );
    return results.map((r) => CategoryModel.fromMap(r)).toList();
  }
}
