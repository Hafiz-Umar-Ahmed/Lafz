import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lafz/core/enums/enums.dart';
import 'package:lafz/core/models/personality.dart';
import 'package:lafz/core/models/quote.dart';
import 'package:lafz/core/providers/providers.dart';
import 'package:lafz/features/library/widgets/quote_card.dart';

class PersonalityScreen extends ConsumerStatefulWidget {
  final int personalityId;
  const PersonalityScreen({super.key, required this.personalityId});

  @override
  ConsumerState<PersonalityScreen> createState() => _PersonalityScreenState();
}

class _PersonalityScreenState extends ConsumerState<PersonalityScreen> {
  PersonalityModel? _personality;
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
    final pRepo = ref.read(personalitiesRepositoryProvider);
    final qRepo = ref.read(quotesRepositoryProvider);
    final favRepo = ref.read(favoritesRepositoryProvider);
    final collRepo = ref.read(collectionsRepositoryProvider);

    final p = await pRepo.getPersonalityById(widget.personalityId);
    final quotes = await qRepo.getQuotesByPersonality(widget.personalityId);
    final favIds = (await favRepo.getFavoriteQuoteIds()).toSet();
    final isFollowing = await collRepo.isFollowing(widget.personalityId, CollectionType.personality);

    if (mounted) {
      setState(() {
        _personality = p;
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
      await collRepo.unfollowCollection(widget.personalityId, CollectionType.personality);
    } else {
      await collRepo.followCollection(widget.personalityId, CollectionType.personality);
    }
    setState(() => _isFollowing = !_isFollowing);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFollowing ? 'Following ${_personality?.name}' : 'Unfollowed ${_personality?.name}'),
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

    if (_personality == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Personality not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_personality!.name),
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
          // Hero Personality Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                margin: EdgeInsets.zero,
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                        child: Text(
                          _personality!.name.substring(0, 1),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _personality!.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            if (_personality!.description != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _personality!.description!,
                                style: const TextStyle(fontSize: 13.5, height: 1.4),
                              ),
                            ],
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: _toggleFollow,
                              icon: Icon(_isFollowing ? Icons.check : Icons.add, size: 18),
                              label: Text(_isFollowing ? 'Following' : 'Follow'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Quotes list
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Wisdom (${_quotes.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
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
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
