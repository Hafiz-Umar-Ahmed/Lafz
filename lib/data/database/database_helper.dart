import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lafz/core/constants/app_constants.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();
  DatabaseHelper.withDatabase(this._database);

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    await _ensureSeeded(_database!);
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbDirectory = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dbDirectory.path, AppConstants.dbName);

    return await openDatabase(
      dbPath,
      version: AppConstants.currentSchemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _ensureSeeded(Database db) async {
    try {
      final res = await db.rawQuery('SELECT COUNT(*) as count FROM quotes');
      final count = (res.first['count'] as num?)?.toInt() ?? 0;
      if (count == 0) {
        await _seedBaselineContent(db);
      }
    } catch (_) {}
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Categories
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        parent_id INTEGER,
        description TEXT,
        sort_order INTEGER DEFAULT 0,
        publication_status TEXT DEFAULT 'published',
        tier TEXT DEFAULT 'free',
        FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');

    // 2. Personalities
    await db.execute('''
      CREATE TABLE personalities (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        category_id INTEGER NOT NULL,
        image_path TEXT,
        publication_status TEXT DEFAULT 'published',
        tier TEXT DEFAULT 'free',
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');

    // 3. Quotes
    await db.execute('''
      CREATE TABLE quotes (
        id INTEGER PRIMARY KEY,
        text TEXT NOT NULL,
        attribution TEXT NOT NULL,
        personality_id INTEGER NOT NULL,
        language TEXT DEFAULT 'en',
        source_title TEXT,
        source_reference TEXT,
        source_url TEXT,
        original_text TEXT,
        original_language TEXT,
        translation_source TEXT,
        verification_status TEXT DEFAULT 'verified',
        publication_status TEXT DEFAULT 'published',
        content_version INTEGER DEFAULT 1,
        tier TEXT DEFAULT 'free',
        surah INTEGER,
        ayah INTEGER,
        hadith_collection TEXT,
        hadith_reference TEXT,
        hadith_grading TEXT,
        FOREIGN KEY (personality_id) REFERENCES personalities(id) ON DELETE CASCADE
      )
    ''');

    // 4. Quote Categories
    await db.execute('''
      CREATE TABLE quote_categories (
        quote_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        PRIMARY KEY (quote_id, category_id),
        FOREIGN KEY (quote_id) REFERENCES quotes(id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');

    // 5. Backgrounds
    await db.execute('''
      CREATE TABLE backgrounds (
        id INTEGER PRIMARY KEY,
        type TEXT NOT NULL,
        file_path TEXT NOT NULL,
        focal_x REAL DEFAULT 0.5,
        focal_y REAL DEFAULT 0.5,
        license TEXT NOT NULL,
        attribution TEXT,
        tier TEXT DEFAULT 'free'
      )
    ''');

    // 6. Favorites
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quote_id INTEGER UNIQUE NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        deleted_at TEXT,
        FOREIGN KEY (quote_id) REFERENCES quotes(id) ON DELETE CASCADE
      )
    ''');

    // 7. Followed Collections
    await db.execute('''
      CREATE TABLE followed_collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        collection_id INTEGER NOT NULL,
        collection_type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');

    // 8. Surface Collections (Widget vs Wallpaper separate collections)
    await db.execute('''
      CREATE TABLE surface_collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        surface TEXT NOT NULL,
        collection_id INTEGER NOT NULL,
        collection_type TEXT NOT NULL,
        enabled INTEGER DEFAULT 1
      )
    ''');

    // 9. User Collections & Items
    await db.execute('''
      CREATE TABLE user_collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE user_collection_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        collection_id INTEGER NOT NULL,
        quote_id INTEGER NOT NULL,
        sort_order INTEGER DEFAULT 0,
        FOREIGN KEY (collection_id) REFERENCES user_collections(id) ON DELETE CASCADE
      )
    ''');

    // 10. User Quotes (Personal, unverified quotes)
    await db.execute('''
      CREATE TABLE user_quotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        attribution TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');

    // 11. Rotation Settings
    await db.execute('''
      CREATE TABLE rotation_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        surface TEXT UNIQUE NOT NULL,
        enabled INTEGER DEFAULT 1,
        schedule_type TEXT DEFAULT 'interval',
        interval_hours INTEGER DEFAULT 12,
        times_json TEXT,
        routine TEXT,
        include_favorites INTEGER DEFAULT 1,
        current_quote_id INTEGER,
        last_rotation_at TEXT,
        next_rotation_at TEXT,
        shuffle_bag_json TEXT,
        content_version INTEGER DEFAULT 1
      )
    ''');

    // 12. Wallpaper Settings
    await db.execute('''
      CREATE TABLE wallpaper_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        preset TEXT DEFAULT 'minimal',
        background_id INTEGER,
        font TEXT DEFAULT 'Plus Jakarta Sans',
        text_alignment TEXT DEFAULT 'center',
        text_size REAL DEFAULT 22.0,
        overlay_opacity REAL DEFAULT 0.38,
        palette TEXT DEFAULT 'dark',
        show_attribution INTEGER DEFAULT 1,
        show_source INTEGER DEFAULT 1,
        destination TEXT DEFAULT 'lockScreen',
        background_color INTEGER,
        text_color INTEGER
      )
    ''');

    // 13. Content Meta
    await db.execute('''
      CREATE TABLE content_meta (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        installed_version INTEGER DEFAULT 1,
        checksum TEXT,
        installed_at TEXT NOT NULL
      )
    ''');

    // 14. Full-Text Search (FTS) Table for instantaneous search
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE quotes_fts USING fts5(
          quote_id UNINDEXED,
          text,
          attribution,
          source_title
        )
      ''');
    } catch (_) {
      // Fallback if FTS5 is not compiled in specific embedded SQLite
    }

    // Seed initial baseline content
    await _seedBaselineContent(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Versioned migrations per NFR-03
  }

  Future<void> _seedBaselineContent(Database db) async {
    try {
      final jsonString = await rootBundle.loadString(
        AppConstants.baselinePackageAsset,
      );
      final Map<String, dynamic> package = jsonDecode(jsonString);

      final manifest = package['manifest'] as Map<String, dynamic>? ?? {};
      final categories = package['categories'] as List? ?? [];
      final personalities = package['personalities'] as List? ?? [];
      final backgrounds = package['backgrounds'] as List? ?? [];
      final quotes = package['quotes'] as List? ?? [];

      await db.transaction((txn) async {
        // Insert Categories
        final catBatch = txn.batch();
        for (final cat in categories) {
          catBatch.insert('categories', {
            'id': cat['id'],
            'name': cat['name'],
            'parent_id': cat['parent_id'],
            'description': cat['description'],
            'sort_order': cat['sort_order'] ?? 0,
            'publication_status': cat['publication_status'] ?? 'published',
            'tier': cat['tier'] ?? 'free',
          });
        }
        await catBatch.commit(noResult: true);

        // Insert Personalities
        final pBatch = txn.batch();
        for (final p in personalities) {
          pBatch.insert('personalities', {
            'id': p['id'],
            'name': p['name'],
            'description': p['description'],
            'category_id': p['category_id'],
            'image_path': p['image_path'],
            'publication_status': p['publication_status'] ?? 'published',
            'tier': p['tier'] ?? 'free',
          });
        }
        await pBatch.commit(noResult: true);

        // Insert Backgrounds
        final bgBatch = txn.batch();
        for (final bg in backgrounds) {
          bgBatch.insert('backgrounds', {
            'id': bg['id'],
            'type': bg['type'],
            'file_path': bg['file_path'],
            'focal_x': bg['focal_x'] ?? 0.5,
            'focal_y': bg['focal_y'] ?? 0.5,
            'license': bg['license'] ?? 'Public Domain',
            'attribution': bg['attribution'],
            'tier': bg['tier'] ?? 'free',
          });
        }
        await bgBatch.commit(noResult: true);

        // Insert Quotes & QuoteCategories
        final qBatch = txn.batch();
        for (final q in quotes) {
          final id = q['id'];
          final source = q['source'] as Map? ?? {};
          final islamic = q['islamic'] as Map? ?? {};

          qBatch.insert('quotes', {
            'id': id,
            'text': q['text'],
            'attribution': q['attribution'],
            'personality_id': q['personality_id'],
            'language': q['language'] ?? 'en',
            'source_title': source['title'],
            'source_reference': source['reference'],
            'source_url': source['url'],
            'original_text': islamic['arabic'],
            'original_language': islamic['arabic'] != null ? 'ar' : null,
            'translation_source': islamic['translation_source'],
            'verification_status': q['verification']?['status'] ?? 'verified',
            'publication_status': q['publication']?['status'] ?? 'published',
            'content_version': q['publication']?['version'] ?? 1,
            'tier': q['tier'] ?? 'free',
            'surah': islamic['surah'],
            'ayah': islamic['ayah'],
            'hadith_collection': islamic['collection'],
            'hadith_reference': islamic['hadith_ref'],
            'hadith_grading': islamic['grading'],
          });

          // Join table
          final catIds = q['category_ids'] as List? ?? [];
          for (final cid in catIds) {
            qBatch.insert('quote_categories', {
              'quote_id': id,
              'category_id': cid,
            });
          }
        }
        await qBatch.commit(noResult: true);

        // Optional FTS Index (done separately so it never blocks or rolls back content)
        try {
          final ftsTables = await txn.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='quotes_fts'",
          );
          if (ftsTables.isNotEmpty) {
            final ftsBatch = txn.batch();
            for (final q in quotes) {
              final id = q['id'];
              final source = q['source'] as Map? ?? {};
              ftsBatch.rawInsert(
                'INSERT INTO quotes_fts(quote_id, text, attribution, source_title) VALUES(?, ?, ?, ?)',
                [id, q['text'], q['attribution'], source['title'] ?? ''],
              );
            }
            await ftsBatch.commit(noResult: true);
          }
        } catch (_) {}

        // Initialize default rotation settings for Widget and Wallpaper surfaces
        await txn.insert('rotation_settings', {
          'surface': 'widget',
          'enabled': 1,
          'schedule_type': 'interval',
          'interval_hours': 12,
          'times_json': jsonEncode([8, 20]),
          'include_favorites': 1,
          'current_quote_id': 1,
          'last_rotation_at': DateTime.now().toIso8601String(),
          'next_rotation_at': DateTime.now()
              .add(const Duration(hours: 12))
              .toIso8601String(),
          'shuffle_bag_json': jsonEncode([]),
          'content_version': 1,
        });

        await txn.insert('rotation_settings', {
          'surface': 'wallpaper',
          'enabled': 1,
          'schedule_type': 'interval',
          'interval_hours': 24,
          'times_json': jsonEncode([7]),
          'include_favorites': 1,
          'current_quote_id': 1,
          'last_rotation_at': DateTime.now().toIso8601String(),
          'next_rotation_at': DateTime.now()
              .add(const Duration(hours: 24))
              .toIso8601String(),
          'shuffle_bag_json': jsonEncode([]),
          'content_version': 1,
        });

        // Initialize Wallpaper Settings
        await txn.insert('wallpaper_settings', {
          'preset': 'minimal',
          'background_id': 1,
          'font': 'Playfair Display',
          'text_alignment': 'center',
          'text_size': 22.0,
          'overlay_opacity': 0.38,
          'palette': 'dark',
          'show_attribution': 1,
          'show_source': 1,
          'destination': 'lockScreen',
        });

        // Initialize Content Meta
        await txn.insert('content_meta', {
          'installed_version': manifest['version'] ?? 1,
          'checksum': manifest['checksum'],
          'installed_at': DateTime.now().toIso8601String(),
        });

        // Default follow top categories
        for (final rootCatId in [1, 2, 3]) {
          await txn.insert('followed_collections', {
            'collection_id': rootCatId,
            'collection_type': 'category',
            'created_at': DateTime.now().toIso8601String(),
          });
          await txn.insert('surface_collections', {
            'surface': 'widget',
            'collection_id': rootCatId,
            'collection_type': 'category',
            'enabled': 1,
          });
          await txn.insert('surface_collections', {
            'surface': 'wallpaper',
            'collection_id': rootCatId,
            'collection_type': 'category',
            'enabled': 1,
          });
        }
      });
    } catch (e) {
      // In tests or headless environments where asset bundle isn't available
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
