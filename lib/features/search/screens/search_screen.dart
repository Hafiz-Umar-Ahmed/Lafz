import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lafz/core/models/personality.dart';
import 'package:lafz/core/models/quote.dart';
import 'package:lafz/core/providers/providers.dart';
import 'package:lafz/features/library/widgets/quote_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  String _filter = 'all'; // 'all', 'quotes', 'thinkers'
  List<QuoteModel> _quotes = [];
  List<PersonalityModel> _personalities = [];
  Set<int> _favoriteQuoteIds = {};
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favRepo = ref.read(favoritesRepositoryProvider);
    final favIds = (await favRepo.getFavoriteQuoteIds()).toSet();
    if (mounted) setState(() => _favoriteQuoteIds = favIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _quotes = [];
        _personalities = [];
        _isSearching = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      setState(() => _isSearching = true);
      final qRepo = ref.read(quotesRepositoryProvider);
      final pRepo = ref.read(personalitiesRepositoryProvider);

      final foundQuotes = await qRepo.searchQuotes(query);
      final foundPersonalities = await pRepo.searchPersonalities(query);

      if (mounted) {
        setState(() {
          _quotes = foundQuotes;
          _personalities = foundPersonalities;
          _isSearching = false;
        });
      }
    });
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search quotes, thinkers, sources...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            fillColor: Colors.transparent,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
          ),
          onChanged: _onSearchChanged,
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filter == 'all',
                  onSelected: (val) => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Quotes (${_quotes.length})'),
                  selected: _filter == 'quotes',
                  onSelected: (val) => setState(() => _filter = 'quotes'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Thinkers (${_personalities.length})'),
                  selected: _filter == 'thinkers',
                  onSelected: (val) => setState(() => _filter = 'thinkers'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Search Results or Empty State
          Expanded(
            child: _buildResults(theme, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(ThemeData theme, bool isDark) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchController.text.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text(
              'Search across 200+ verified wisdom items',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    final showQuotes = _filter == 'all' || _filter == 'quotes';
    final showThinkers = _filter == 'all' || _filter == 'thinkers';

    final hasResults = (_quotes.isNotEmpty && showQuotes) ||
        (_personalities.isNotEmpty && showThinkers);

    if (!hasResults) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sentiment_dissatisfied, size: 54, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text(
              'No results found for "${_searchController.text}"',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Thinkers Section
        if (showThinkers && _personalities.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              'Thinkers (${_personalities.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ..._personalities.map((p) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              )),
          const SizedBox(height: 10),
        ],

        // Quotes Section
        if (showQuotes && _quotes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              'Quotes (${_quotes.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ..._quotes.map((q) => QuoteCard(
                quote: q,
                isFavorite: _favoriteQuoteIds.contains(q.id),
                onTap: () => context.push('/quote/${q.id}'),
                onFavoriteToggle: () => _toggleFavorite(q.id),
                onShare: () => Share.share(
                  '“${q.text}” — ${q.attribution}\n\nShared via Lafz',
                ),
              )),
        ],
      ],
    );
  }
}
