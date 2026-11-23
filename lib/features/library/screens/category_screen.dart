import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lafz/core/enums/enums.dart';
import 'package:lafz/core/models/category.dart';
import 'package:lafz/core/models/personality.dart';
import 'package:lafz/core/models/quote.dart';
import 'package:lafz/core/providers/providers.dart';
import 'package:lafz/features/library/widgets/quote_card.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  final int categoryId;
  const CategoryScreen({super.key, required this.categoryId});

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  CategoryModel? _category;
  List<CategoryModel> _subcategories = [];
  List<PersonalityModel> _personalities = [];
  List<QuoteModel> _quotes = [];
  Set<int> _favoriteQuoteIds = {};
  bool _isFollowing = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final catRepo = ref.read(categoriesRepositoryProvider);
    final pRepo = ref.read(personalitiesRepositoryProvider);
    final qRepo = ref.read(quotesRepositoryProvider);
    final favRepo = ref.read(favoritesRepositoryProvider);
    final collRepo = ref.read(collectionsRepositoryProvider);

    final cat = await catRepo.getCategoryById(widget.categoryId);
    final subs = await catRepo.getSubcategories(widget.categoryId);
    final persons = await pRepo.getPersonalitiesByCategory(widget.categoryId);
    final quotes = await qRepo.getQuotesByCategory(widget.categoryId);
    final favIds = (await favRepo.getFavoriteQuoteIds()).toSet();
    final isFollowing = await collRepo.isFollowing(widget.categoryId, CollectionType.category);

    if (mounted) {
      setState(() {
        _category = cat;
        _subcategories = subs;
        _personalities = persons;
        _quotes = quotes;
        _favoriteQuoteIds = favIds;
        _isFollowing = isFollowing;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final collRepo = ref.read(collectionsRepositoryProvider);
    if (_isFollowing) {
      await collRepo.unfollowCollection(widget.categoryId, CollectionType.category);
    } else {
      await collRepo.followCollection(widget.categoryId, CollectionType.category);
    }
    setState(() => _isFollowing = !_isFollowing);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFollowing ? 'Followed category' : 'Unfollowed category'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleFavorite(int quoteId) async {
    final favRepo = ref.read(favoritesRepositoryProvider);
    final isFav = await favRepo.toggleFavorite(quoteId);
    setState(() {
      if (isFav) {
        _favoriteQuoteIds.add(quoteId);
      } else {
        _favoriteQuoteIds.remove(quoteId);
      }
    });
    ref.read(favoritesVersionProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_category == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Category not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_category!.name),
        actions: [
          IconButton(
            icon: Icon(_isFollowing ? Icons.notifications_active : Icons.notifications_none),
            tooltip: _isFollowing ? 'Unfollow' : 'Follow',
            onPressed: _toggleFollow,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Category Description & Follow Banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                margin: EdgeInsets.zero,
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _category!.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (_category!.description != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _category!.description!,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: _toggleFollow,
                        icon: Icon(_isFollowing ? Icons.check : Icons.add),
                        label: Text(_isFollowing ? 'Following Category' : 'Follow Category'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Subcategories if any
          if (_subcategories.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text('Subcategories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final sub = _subcategories[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(sub.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(sub.description ?? ''),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/category/${sub.id}'),
                      ),
                    );
                  },
                  childCount: _subcategories.length,
                ),
              ),
            ),
          ],

          // Personalities in this category if any
          if (_personalities.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Thinkers & Sources', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final p = _personalities[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                          child: Text(
                            p.name.substring(0, 1),
                            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                          ),
                        ),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(p.description ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/personality/${p.id}'),
                      ),
                    );
                  },
                  childCount: _personalities.length,
                ),
              ),
            ),
          ],

          // Quotes in this category
          if (_quotes.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Wisdom', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final q = _quotes[index];
                  return QuoteCard(
                    quote: q,
                    isFavorite: _favoriteQuoteIds.contains(q.id),
                    onTap: () => context.push('/quote/${q.id}'),
                    onFavoriteToggle: () => _toggleFavorite(q.id),
                    onShare: () => Share.share(
                      '“${q.text}” — ${q.attribution}\n\nShared via Lafz',
                    ),
                  );
                },
                childCount: _quotes.length,
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
