import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lafz/core/enums/enums.dart';
import 'package:lafz/data/database/database_helper.dart';
import 'package:lafz/data/repositories/categories_repository.dart';
import 'package:lafz/data/repositories/collections_repository.dart';
import 'package:lafz/data/repositories/favorites_repository.dart';
import 'package:lafz/data/repositories/personalities_repository.dart';
import 'package:lafz/data/repositories/quotes_repository.dart';
import 'package:lafz/data/repositories/rotation_repository.dart';
import 'package:lafz/data/repositories/settings_repository.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

final quotesRepositoryProvider = Provider<QuotesRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return QuotesRepository(dbHelper);
});

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return CategoriesRepository(dbHelper);
});

final personalitiesRepositoryProvider = Provider<PersonalitiesRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return PersonalitiesRepository(dbHelper);
});

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return FavoritesRepository(dbHelper);
});

final collectionsRepositoryProvider = Provider<CollectionsRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return CollectionsRepository(dbHelper);
});

final rotationRepositoryProvider = Provider<RotationRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  final quotesRepo = ref.watch(quotesRepositoryProvider);
  final favoritesRepo = ref.watch(favoritesRepositoryProvider);
  return RotationRepository(
    dbHelper: dbHelper,
    quotesRepo: quotesRepo,
    favoritesRepo: favoritesRepo,
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return SettingsRepository(dbHelper);
});

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.system;
});

final favoritesVersionProvider = StateProvider<int>((ref) {
  return 0;
});

final appLanguageProvider = StateProvider<AppLanguage>((ref) {
  return AppLanguage.english;
});

final isOnboardingCompleteProvider = StateProvider<bool>((ref) {
  return false;
});
