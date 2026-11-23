import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lafz/core/models/quote.dart';
import 'package:lafz/core/providers/providers.dart';
import 'package:lafz/features/library/widgets/quote_card.dart';

class CollectionDetailScreen extends ConsumerStatefulWidget {
  final int collectionId;
  const CollectionDetailScreen({super.key, required this.collectionId});

  @override
  ConsumerState<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends ConsumerState<CollectionDetailScreen> {
  List<QuoteModel> _quotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCollectionQuotes();
  }

  Future<void> _loadCollectionQuotes() async {
    final collRepo = ref.read(collectionsRepositoryProvider);
    final quotes = await collRepo.getCollectionQuotes(widget.collectionId);
    if (mounted) {
      setState(() {
        _quotes = quotes;
        _isLoading = false;
      });
    }
  }

  void _showAddQuotesPicker() async {
    final qRepo = ref.read(quotesRepositoryProvider);
    final allQuotes = await qRepo.getAllPublishedQuotes(limit: 50);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Quotes to Playlist',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: allQuotes.length,
                    itemBuilder: (context, index) {
                      final q = allQuotes[index];
                      final alreadyIn = _quotes.any((existing) => existing.id == q.id);

                      return ListTile(
                        title: Text(
                          '“${q.text}”',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5),
                        ),
                        subtitle: Text(q.attribution, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: alreadyIn
                            ? const Icon(Icons.check, color: Colors.green)
                            : IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () async {
                                  final collRepo = ref.read(collectionsRepositoryProvider);
                                  await collRepo.addQuoteToCollection(widget.collectionId, q.id);
                                  _loadCollectionQuotes();
                                  if (context.mounted) Navigator.pop(context);
                                },
                              ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Playlist (${_quotes.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add quotes',
            onPressed: _showAddQuotesPicker,
          ),
        ],
      ),
      body: _quotes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.format_quote_outlined, size: 54, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No quotes in this playlist yet', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _showAddQuotesPicker,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Quotes'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: _quotes.length,
              itemBuilder: (context, index) {
                final q = _quotes[index];
                return QuoteCard(
                  quote: q,
                  onTap: () => context.push('/quote/${q.id}'),
                );
              },
            ),
    );
  }
}
