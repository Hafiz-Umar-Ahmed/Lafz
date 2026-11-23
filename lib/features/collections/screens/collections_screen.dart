import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lafz/core/enums/enums.dart';
import 'package:lafz/core/models/user_collection.dart';
import 'package:lafz/core/providers/providers.dart';
import 'package:lafz/data/repositories/collections_repository.dart';

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<FollowedCollectionItem> _followed = [];
  Map<String, Set<int>> _surfaceEnabled = {
    'widget': {},
    'wallpaper': {},
  };
  List<UserCollectionModel> _userCollections = [];
  List<UserQuoteModel> _userQuotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final collRepo = ref.read(collectionsRepositoryProvider);
    final followed = await collRepo.getFollowedCollections();
    final widgetColls = await collRepo.getSurfaceCollections(SurfaceType.widget);
    final wallpaperColls = await collRepo.getSurfaceCollections(SurfaceType.wallpaper);
    final userColls = await collRepo.getUserCollections();
    final userQuotes = await collRepo.getUserQuotes();

    final wEnabled = widgetColls
        .where((r) => (r['enabled'] as int? ?? 1) == 1)
        .map((r) => r['collection_id'] as int)
        .toSet();

    final wpEnabled = wallpaperColls
        .where((r) => (r['enabled'] as int? ?? 1) == 1)
        .map((r) => r['collection_id'] as int)
        .toSet();

    if (mounted) {
      setState(() {
        _followed = followed;
        _surfaceEnabled = {
          'widget': wEnabled,
          'wallpaper': wpEnabled,
        };
        _userCollections = userColls;
        _userQuotes = userQuotes;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSurfaceCollection({
    required SurfaceType surface,
    required FollowedCollectionItem item,
    required bool enabled,
  }) async {
    final collRepo = ref.read(collectionsRepositoryProvider);
    await collRepo.setSurfaceCollectionEnabled(
      surface: surface,
      collectionId: item.collectionId,
      type: item.type,
      enabled: enabled,
    );

    setState(() {
      if (enabled) {
        _surfaceEnabled[surface.name]?.add(item.collectionId);
      } else {
        _surfaceEnabled[surface.name]?.remove(item.collectionId);
      }
    });
  }

  void _showCreateCollectionDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Collection'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Collection Name',
            hintText: 'e.g. Daily Stoic, Focus Quotes',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                final collRepo = ref.read(collectionsRepositoryProvider);
                await collRepo.createUserCollection(name);
                if (context.mounted) Navigator.pop(context);
                _loadData();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddPersonalQuoteDialog() {
    final textController = TextEditingController();
    final authorController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Personal Quote'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Quote Text *',
                  hintText: 'Enter your personal wisdom...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: authorController,
                decoration: const InputDecoration(
                  labelText: 'Attribution (Optional)',
                  hintText: 'e.g. Mentor, Grandfather, Self',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Where you heard it or context',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                final collRepo = ref.read(collectionsRepositoryProvider);
                await collRepo.createUserQuote(
                  text: text,
                  attribution: authorController.text.trim().isEmpty ? null : authorController.text.trim(),
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );
                if (context.mounted) Navigator.pop(context);
                _loadData();
              }
            },
            child: const Text('Save Quote'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          tabs: const [
            Tab(text: 'Following'),
            Tab(text: 'My Playlists'),
            Tab(text: 'Personal Quotes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFollowingTab(theme, isDark),
          _buildMyPlaylistsTab(theme, isDark),
          _buildPersonalQuotesTab(theme, isDark),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? null
          : FloatingActionButton(
              onPressed: _tabController.index == 1
                  ? _showCreateCollectionDialog
                  : _showAddPersonalQuoteDialog,
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildFollowingTab(ThemeData theme, bool isDark) {
    if (_followed.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.collections_bookmark_outlined, size: 54, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            const Text('Not following any collections yet', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Browse thinkers and categories and tap Follow to queue them.'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _followed.length,
      itemBuilder: (context, index) {
        final item = _followed[index];
        final wEnabled = _surfaceEnabled['widget']?.contains(item.collectionId) ?? false;
        final wpEnabled = _surfaceEnabled['wallpaper']?.contains(item.collectionId) ?? false;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Chip(
                      label: Text(item.type.label, style: const TextStyle(fontSize: 10.5)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Independent surface controls (PRD FR-006):',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      avatar: Icon(Icons.widgets, size: 14, color: wEnabled ? Colors.white : null),
                      label: const Text('Widget Surface'),
                      selected: wEnabled,
                      onSelected: (val) => _toggleSurfaceCollection(
                        surface: SurfaceType.widget,
                        item: item,
                        enabled: val,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: Icon(Icons.wallpaper, size: 14, color: wpEnabled ? Colors.white : null),
                      label: const Text('Wallpaper Surface'),
                      selected: wpEnabled,
                      onSelected: (val) => _toggleSurfaceCollection(
                        surface: SurfaceType.wallpaper,
                        item: item,
                        enabled: val,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMyPlaylistsTab(ThemeData theme, bool isDark) {
    if (_userCollections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.playlist_add, size: 54, color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 12),
              const Text('No custom playlists yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 6),
              Text(
                'Group your chosen wisdom into personal named playlists.',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FilledButton.icon(
                  onPressed: _showCreateCollectionDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create Playlist'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userCollections.length,
      itemBuilder: (context, index) {
        final coll = _userCollections[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              child: Icon(Icons.folder_special_outlined, color: theme.colorScheme.primary),
            ),
            title: Text(coll.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${coll.quoteCount} quotes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/collection/${coll.id}'),
          ),
        );
      },
    );
  }

  Widget _buildPersonalQuotesTab(ThemeData theme, bool isDark) {
    if (_userQuotes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_note, size: 54, color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 12),
              const Text('No private quotes added', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 6),
              Text(
                'Add personal quotes. They carry a Personal label and stay private.',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FilledButton.icon(
                  onPressed: _showAddPersonalQuoteDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Private Quote'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userQuotes.length,
      itemBuilder: (context, index) {
        final uq = _userQuotes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Personal',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () async {
                        final collRepo = ref.read(collectionsRepositoryProvider);
                        await collRepo.deleteUserQuote(uq.id);
                        _loadData();
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '“${uq.text}”',
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500),
                ),
                if (uq.attribution != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '— ${uq.attribution}',
                    style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
