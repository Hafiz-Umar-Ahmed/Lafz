import 'package:sqflite/sqflite.dart';
import 'package:lafz/core/models/background.dart';
import 'package:lafz/core/models/content_meta.dart';
import 'package:lafz/core/models/wallpaper_settings.dart';
import 'package:lafz/data/database/database_helper.dart';

class SettingsRepository {
  final DatabaseHelper _dbHelper;
  SettingsRepository([DatabaseHelper? dbHelper])
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  Future<WallpaperSettingsModel> getWallpaperSettings() async {
    final db = await _db;
    final results = await db.query('wallpaper_settings', limit: 1);
    if (results.isEmpty) {
      return const WallpaperSettingsModel();
    }
    return WallpaperSettingsModel.fromMap(results.first);
  }

  Future<void> updateWallpaperSettings(WallpaperSettingsModel settings) async {
    final db = await _db;
    final map = settings.toMap();
    final count = await db.update('wallpaper_settings', map);
    if (count == 0) {
      map['id'] = 1;
      await db.insert(
        'wallpaper_settings',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<BackgroundModel>> getBackgrounds() async {
    final db = await _db;
    final results = await db.query('backgrounds', orderBy: 'id ASC');
    return results.map((r) => BackgroundModel.fromMap(r)).toList();
  }

  Future<ContentMetaModel> getContentMeta() async {
    final db = await _db;
    final results = await db.query('content_meta', limit: 1);
    if (results.isEmpty) {
      return ContentMetaModel(
        installedVersion: 1,
        installedAt: DateTime.now(),
      );
    }
    return ContentMetaModel.fromMap(results.first);
  }
}
