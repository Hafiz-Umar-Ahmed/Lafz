import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lafz/core/enums/enums.dart';
import 'package:lafz/core/models/quote.dart';
import 'package:lafz/core/providers/providers.dart';
import 'package:lafz/features/library/widgets/quote_card.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  List<QuoteModel> _favorites = [];
  bool _includeInRotation = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favRepo = ref.read(favoritesRepositoryProvider);
    final rotRepo = ref.read(rotationRepositoryProvider);

    final favs = await favRepo.getFavorites();
    final rotSettings = await rotRepo.getRotationSettings(SurfaceType.widget);

    if (mounted) {
      setState(() {
        _favorites = favs;
        _includeInRotation = rotSettings.includeFavorites;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleIncludeInRotation(bool val) async {
    final rotRepo = ref.read(rotationRepositoryProvider);
    final wSettings = await rotRepo.getRotationSettings(SurfaceType.widget);
    final wpSettings = await rotRepo.getRotationSettings(SurfaceType.wallpaper);

    await rotRepo.updateRotationSettings(wSettings.copyWith(includeFavorites: val));
    await rotRepo.updateRotationSettings(wpSettings.copyWith(includeFavorites: val));

    setState(() => _includeInRotation = val);
  }

  Future<void> _removeFavorite(QuoteModel quote, int index) async {
    final favRepo = ref.read(favoritesRepositoryProvider);
    await favRepo.removeFavorite(quote.id);

    setState(() {
      _favorites.removeAt(index);
    });

    ref.read(favoritesVersionProvider.notifier).state++;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Removed from favorites'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await favRepo.addFavorite(quote.id);
              ref.read(favoritesVersionProvider.notifier).state++;
              _loadFavorites();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(favoritesVersionProvider, (prev, next) {
      _loadFavorites();
    });

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Favorites (${_favorites.length})'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFavorites,
        child: _favorites.isEmpty
            ? Center(
                child: ListView(
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Icon(
                      Icons.bookmark_border,
                      size: 64,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        'No favorites yet',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Tap the bookmark icon on any wisdom card to save it here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                // Rotation Source Toggle Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: SwitchListTile(
                        title: const Text(
                          'Include in Rotation',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Allow your favorites to appear on home screen and wallpapers',
                          style: TextStyle(fontSize: 12.5),
                        ),
                        value: _includeInRotation,
                        activeThumbColor: theme.colorScheme.primary,
                        onChanged: _toggleIncludeInRotation,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 6)),

                // Favorites List
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final q = _favorites[index];
                      return Dismissible(
                        key: ValueKey(q.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          color: Colors.redAccent.withValues(alpha: 0.8),
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        onDismissed: (_) => _removeFavorite(q, index),
                        child: QuoteCard(
                          quote: q,
                          isFavorite: true,
                          onTap: () => context.push('/quote/${q.id}'),
                          onFavoriteToggle: () => _removeFavorite(q, index),
                          onShare: () => Share.share(
                            '“${q.text}” — ${q.attribution}\n\nShared via Lafz',
                          ),
                        ),
                      );
                    },
                    childCount: _favorites.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
      ),
    );
  }
}
