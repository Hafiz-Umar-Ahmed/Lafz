import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lafz/core/models/category.dart';
import 'package:lafz/core/models/personality.dart';
import 'package:lafz/core/models/quote.dart';
import 'package:lafz/core/providers/providers.dart';
import 'package:lafz/features/library/widgets/quote_card.dart';


class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  QuoteModel? _featuredQuote;
  List<PersonalityModel> _featuredPersonalities = [];
  List<CategoryModel> _categories = [];
  List<QuoteModel> _recentQuotes = [];
  Set<int> _favoriteQuoteIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final qRepo = ref.read(quotesRepositoryProvider);
    final pRepo = ref.read(personalitiesRepositoryProvider);
    final cRepo = ref.read(categoriesRepositoryProvider);
    final favRepo = ref.read(favoritesRepositoryProvider);

    final featured = await qRepo.getQuoteById(1);
    final persons = await pRepo.getFeaturedPersonalities();
    final cats = await cRepo.getRootCategories();
    final recents = await qRepo.getAllPublishedQuotes(limit: 25);
    final favIds = (await favRepo.getFavoriteQuoteIds()).toSet();

    if (mounted) {
      setState(() {
        _featuredQuote = featured;
        _featuredPersonalities = persons;
        _categories = cats;
        _recentQuotes = recents;
        _favoriteQuoteIds = favIds;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshFavorites() async {
    final favRepo = ref.read(favoritesRepositoryProvider);
    final favIds = (await favRepo.getFavoriteQuoteIds()).toSet();
    if (mounted) {
      setState(() => _favoriteQuoteIds = favIds);
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
    ref.listen<int>(favoritesVersionProvider, (prev, next) {
      _refreshFavorites();
    });

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          // App Bar with Bilingual Title
          SliverAppBar(
            pinned: true,
            centerTitle: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Lafz',
                  style: TextStyle(
                    fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '•',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Text(
                  'لفظ',
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.amiri(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    height: 1.1,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded),
                tooltip: 'Search',
                onPressed: () => context.push('/search'),
              ),
            ],
          ),

          // iOS-style Search Bar Trigger
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: InkWell(
                onTap: () => context.push('/search'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFFE5E5EA).withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFD1D1D6).withValues(alpha: 0.6),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Search quotes, thinkers, sources...',
                          style: TextStyle(
                            fontSize: 14.5,
                            letterSpacing: -0.2,
                            color: isDark ? Colors.white38 : Colors.black45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          

          // Daily Reflection Banner
          if (_featuredQuote != null) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.wb_sunny_outlined,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'DAILY REFLECTION',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: QuoteCard(
                quote: _featuredQuote!,
                isFavorite: _favoriteQuoteIds.contains(_featuredQuote!.id),
                onTap: () => context.push('/quote/${_featuredQuote!.id}'),
                onFavoriteToggle: () => _toggleFavorite(_featuredQuote!.id),
                onShare: () => Share.share(
                  '“${_featuredQuote!.text}” — ${_featuredQuote!.attribution}\n\nShared via Lafz',
                ),
              ),
            ),
          ],

          // Featured Thinkers & Sources Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Thinkers & Sources',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/category/1'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View all',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 116,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _featuredPersonalities.length,
                itemBuilder: (context, index) {
                  final p = _featuredPersonalities[index];
                  return Container(
                    width: 86,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    child: InkWell(
                      onTap: () => context.push('/personality/${p.id}'),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF2C2C2E)
                                      : const Color(0xFFE5E5EA),
                                  width: 0.8,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                p.name.isNotEmpty ? p.name.substring(0, 1) : '',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              p.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Categories Grid Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: const Text(
                'Explore Wisdom',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.95,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final cat = _categories[index];
                  IconData icon = Icons.auto_stories_outlined;
                  if (cat.name.contains('Islam')) icon = Icons.brightness_3;
                  if (cat.name.contains('Philosophy')) icon = Icons.psychology_outlined;
                  if (cat.name.contains('Modern')) icon = Icons.trending_up;

                  return Card(
                    margin: EdgeInsets.zero,
                    child: InkWell(
                      onTap: () => context.push('/category/${cat.id}'),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              ),
                              child: Icon(
                                icon,
                                size: 24,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              cat.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: _categories.length,
              ),
            ),
          ),

          // Recent Verified Quotes Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 26, 16, 8),
              child: Row(
                children: [
                  const Text(
                    'Curated Wisdom',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_recentQuotes.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final q = _recentQuotes[index];
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
              childCount: _recentQuotes.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}
