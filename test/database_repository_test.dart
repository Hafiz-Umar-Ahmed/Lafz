import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lafz/core/enums/enums.dart';
import 'package:lafz/core/models/quote.dart';
import 'package:lafz/data/database/database_helper.dart';
import 'package:lafz/data/repositories/favorites_repository.dart';
import 'package:lafz/data/repositories/quotes_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Database Schema & Repository Integration Tests (SRS M2)', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      // Create minimal tables
      await db.execute('''
        CREATE TABLE categories (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          parent_id INTEGER,
          description TEXT,
          sort_order INTEGER DEFAULT 0,
          publication_status TEXT DEFAULT 'published',
          tier TEXT DEFAULT 'free'
        )
      ''');

      await db.execute('''
        CREATE TABLE personalities (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          category_id INTEGER NOT NULL,
          image_path TEXT,
          publication_status TEXT DEFAULT 'published',
          tier TEXT DEFAULT 'free'
        )
      ''');

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
          hadith_grading TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE favorites (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          quote_id INTEGER UNIQUE NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          deleted_at TEXT
        )
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('Inserts and queries published quotes with verification status', () async {
      const quote = QuoteModel(
        id: 1,
        text: 'Verily, with hardship comes ease.',
        attribution: 'The Holy Quran',
        personalityId: 101,
        surah: 94,
        ayah: 6,
        originalText: 'إِنَّ مَعَ الْعُسْرِ يُسْرًا',
        verificationStatus: VerificationStatus.verifiedTranslation,
        publicationStatus: PublicationStatus.published,
      );

      await db.insert('quotes', quote.toMap());

      final results = await db.query('quotes', where: 'id = ?', whereArgs: [1]);
      expect(results.length, 1);

      final loaded = QuoteModel.fromMap(results.first);
      expect(loaded.text, quote.text);
      expect(loaded.isDisplayable, isTrue);
      expect(loaded.hasOriginal, isTrue);
      expect(loaded.verificationStatus, VerificationStatus.verifiedTranslation);
    });

    test('Favorites CRUD and soft delete (FR-007 & SRS 6.1)', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('favorites', {
        'quote_id': 42,
        'created_at': now,
      });

      var favs = await db.query('favorites', where: 'deleted_at IS NULL');
      expect(favs.length, 1);
      expect(favs.first['quote_id'], 42);

      // Soft delete
      await db.update(
        'favorites',
        {'deleted_at': DateTime.now().toIso8601String()},
        where: 'quote_id = ?',
        whereArgs: [42],
      );

      favs = await db.query('favorites', where: 'deleted_at IS NULL');
      expect(favs.isEmpty, isTrue);
    });

    test('FavoritesRepository toggleFavorite and getFavorites retrieves favorited quotes', () async {
      final dbHelper = DatabaseHelper.withDatabase(db);
      final favRepo = FavoritesRepository(dbHelper);
      final qRepo = QuotesRepository(dbHelper);

      // Insert test quote
      await db.insert('quotes', {
        'id': 999,
        'text': 'Knowledge is power.',
        'attribution': 'Francis Bacon',
        'personality_id': 1,
        'publication_status': 'published',
        'verification_status': 'verified',
      });

      // Toggle favorite on
      final isFav1 = await favRepo.toggleFavorite(999);
      expect(isFav1, isTrue);
      expect(await favRepo.isFavorite(999), isTrue);

      final favoritesList = await favRepo.getFavorites();
      expect(favoritesList.any((q) => q.id == 999), isTrue);

      // Random quote test
      final randomQ = await qRepo.getRandomQuote();
      expect(randomQ, isNotNull);

      // Toggle favorite off
      final isFav2 = await favRepo.toggleFavorite(999);
      expect(isFav2, isFalse);
      expect(await favRepo.isFavorite(999), isFalse);
    });
  });
}
