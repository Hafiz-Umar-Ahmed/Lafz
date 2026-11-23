import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:lafz/core/enums/enums.dart';
import 'package:lafz/core/models/quote.dart';
import 'package:lafz/core/models/rotation_settings.dart';
import 'package:lafz/core/utils/rotation_engine.dart';
import 'package:lafz/data/database/database_helper.dart';
import 'package:lafz/data/repositories/favorites_repository.dart';
import 'package:lafz/data/repositories/quotes_repository.dart';

class RotationRepository {
  final DatabaseHelper _dbHelper;
  final QuotesRepository _quotesRepo;
  final FavoritesRepository _favoritesRepo;

  RotationRepository({
    DatabaseHelper? dbHelper,
    QuotesRepository? quotesRepo,
    FavoritesRepository? favoritesRepo,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _quotesRepo = quotesRepo ?? QuotesRepository(dbHelper),
        _favoritesRepo = favoritesRepo ?? FavoritesRepository(dbHelper);

  Future<Database> get _db => _dbHelper.database;

  Future<RotationSettingsModel> getRotationSettings(SurfaceType surface) async {
    final db = await _db;
    final results = await db.query(
      'rotation_settings',
      where: 'surface = ?',
      whereArgs: [surface.name],
    );

    if (results.isEmpty) {
      // Default fallback
      return RotationSettingsModel(surface: surface);
    }

    return RotationSettingsModel.fromMap(results.first);
  }

  Future<void> updateRotationSettings(RotationSettingsModel settings) async {
    final db = await _db;
    await db.insert(
      'rotation_settings',
      settings.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Triggers a rotation for the specified surface.
  /// Runs the shuffle bag algorithm, saves state atomically, and returns the newly active quote.
  Future<QuoteModel?> rotateNow(SurfaceType surface) async {
    final db = await _db;
    final settings = await getRotationSettings(surface);

    // 1. Get enabled collections for this surface
    final surfaceColls = await db.query(
      'surface_collections',
      where: 'surface = ? AND enabled = 1',
      whereArgs: [surface.name],
    );

    final catIds = <int>[];
    final pIds = <int>[];

    for (final sc in surfaceColls) {
      final type = sc['collection_type'] as String;
      final collId = sc['collection_id'] as int;
      if (type == 'category' || type == 'subcategory') {
        catIds.add(collId);
      } else if (type == 'personality') {
        pIds.add(collId);
      }
    }

    // 2. Build eligible set
    final collectionQuoteIds = await _quotesRepo.getEligibleQuoteIds(
      categoryIds: catIds,
      personalityIds: pIds,
      includeFavorites: false,
    );

    final favoriteQuoteIds = settings.includeFavorites
        ? await _favoritesRepo.getFavoriteQuoteIds()
        : <int>[];

    final eligibleSet = RotationEngine.buildEligibleSet(
      collectionQuoteIds: collectionQuoteIds,
      favoriteQuoteIds: favoriteQuoteIds,
      includeFavorites: settings.includeFavorites,
    );

    if (eligibleSet.isEmpty) {
      // Fallback: return quote 1 if exists
      return await _quotesRepo.getQuoteById(1);
    }

    // 3. Select next quote using shuffle bag
    final (nextQuoteId, updatedBag) = RotationEngine.selectNext(
      currentQuoteId: settings.currentQuoteId,
      shuffleBag: settings.shuffleBag,
      eligibleSet: eligibleSet,
    );

    final now = DateTime.now();
    final nextTime = RotationEngine.computeNextRotation(
      now: now,
      scheduleType: settings.scheduleType,
      intervalHours: settings.intervalHours,
      specificTimes: settings.specificTimes,
      routine: settings.routine,
    );

    // 4. Save new state in one transaction (SRS 5.1 step 5)
    await db.transaction((txn) async {
      await txn.update(
        'rotation_settings',
        {
          'current_quote_id': nextQuoteId,
          'last_rotation_at': now.toIso8601String(),
          'next_rotation_at': nextTime.toIso8601String(),
          'shuffle_bag_json': jsonEncode(updatedBag),
        },
        where: 'surface = ?',
        whereArgs: [surface.name],
      );
    });

    return await _quotesRepo.getQuoteById(nextQuoteId);
  }
}
