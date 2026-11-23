import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lafz/core/enums/enums.dart';
import 'package:lafz/core/models/personality.dart';
import 'package:lafz/core/models/quote.dart';
import 'package:lafz/core/providers/providers.dart';
import 'package:lafz/native/native_bridge.dart';

class QuoteDetailScreen extends ConsumerStatefulWidget {
  final int quoteId;
  const QuoteDetailScreen({super.key, required this.quoteId});

  @override
  ConsumerState<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends ConsumerState<QuoteDetailScreen> {
  QuoteModel? _quote;
  PersonalityModel? _personality;
  bool _isFavorite = false;
  bool _isFollowingPersonality = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    final qRepo = ref.read(quotesRepositoryProvider);
    final pRepo = ref.read(personalitiesRepositoryProvider);
    final favRepo = ref.read(favoritesRepositoryProvider);
    final collRepo = ref.read(collectionsRepositoryProvider);

    final q = await qRepo.getQuoteById(widget.quoteId);
    if (q != null) {
      final p = await pRepo.getPersonalityById(q.personalityId);
      final isFav = await favRepo.isFavorite(q.id);
      final isFollowing = await collRepo.isFollowing(
        q.personalityId,
        CollectionType.personality,
      );

      if (mounted) {
        setState(() {
          _quote = q;
          _personality = p;
          _isFavorite = isFav;
          _isFollowingPersonality = isFollowing;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_quote == null) return;
    final favRepo = ref.read(favoritesRepositoryProvider);
    final newFav = await favRepo.toggleFavorite(_quote!.id);
    setState(() => _isFavorite = newFav);
    ref.read(favoritesVersionProvider.notifier).state++;
  }

  Future<void> _toggleFollowPersonality() async {
    if (_personality == null) return;
    final collRepo = ref.read(collectionsRepositoryProvider);
    if (_isFollowingPersonality) {
      await collRepo.unfollowCollection(
        _personality!.id,
        CollectionType.personality,
      );
    } else {
      await collRepo.followCollection(
        _personality!.id,
        CollectionType.personality,
      );
    }
    setState(() => _isFollowingPersonality = !_isFollowingPersonality);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFollowingPersonality
                ? 'Following ${_personality!.name}'
                : 'Unfollowed ${_personality!.name}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _setAsWidgetQuote() async {
    if (_quote == null) return;
    await NativeBridge.updateWidgetTimeline(
      quoteText: _quote!.text,
      attribution: _quote!.attribution,
      collectionName: _personality?.name,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Updated home screen widget quote')),
      );
    }
  }

  void _previewWallpaper() {
    if (_quote == null) return;
    context.push('/wallpapers', extra: _quote);
  }

  void _reportQuote() {
    showDialog(
      context: context,
      builder: (context) {
        final textController = TextEditingController();
        return AlertDialog(
          title: const Text('Suggest a Correction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Have a suggested correction for this quote or source reference? Let us know below:',
                style: TextStyle(fontSize: 13.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Describe suggestion or citation...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Thank you! Your feedback has been received.',
                    ),
                  ),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_quote == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Quote not found or revoked')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.bookmark : Icons.bookmark_border,
              color: _isFavorite ? const Color(0xFFC29B38) : null,
            ),
            tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () => Share.share(
              '“${_quote!.text}” — ${_quote!.attribution}\n\nShared via Lafz',
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'report') _reportQuote();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      size: 20,
                      color: Colors.redAccent,
                    ),
                    SizedBox(width: 10),
                    Text('Report incorrect quote'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tier Badge (Free / Premium)
            if (_quote!.tier == ContentTier.premium)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFC29B38).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFC29B38).withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 14, color: Color(0xFFC29B38)),
                    SizedBox(width: 4),
                    Text(
                      'PREMIUM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC29B38),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Original Text (if Arabic / Urdu)
            if (_quote!.hasOriginal) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  _quote!.originalText!,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.amiri(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    height: 2.0,
                    color: isDark
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Main Quote Text
            Text(
              '“${_quote!.text}”',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                height: 1.55,
                color: isDark
                    ? const Color(0xFFF8FAFC)
                    : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),

            // Attribution & Thinker link
            InkWell(
              onTap: () {
                if (_personality != null) {
                  context.push('/personality/${_personality!.id}');
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '— ${_quote!.attribution}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 13,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Source & Attribution Metadata Card
            Card(
              margin: EdgeInsets.zero,
              color: isDark ? const Color(0xFF191D24) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Source & Reference',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_quote!.sourceTitle != null)
                      _buildMetaRow(
                        Icons.book_outlined,
                        'Source',
                        _quote!.sourceTitle!,
                      ),
                    if (_quote!.sourceReference != null)
                      _buildMetaRow(
                        Icons.tag,
                        'Reference',
                        _quote!.sourceReference!,
                      ),
                    if (_quote!.surah != null && _quote!.ayah != null)
                      _buildMetaRow(
                        Icons.auto_stories,
                        'Surah & Ayah',
                        'Surah ${_quote!.surah}, Verse ${_quote!.ayah}',
                      ),
                    if (_quote!.hadithCollection != null)
                      _buildMetaRow(
                        Icons.menu_book,
                        'Hadith Collection',
                        '${_quote!.hadithCollection} (${_quote!.hadithReference ?? ''})',
                      ),
                    if (_quote!.hadithGrading != null)
                      _buildMetaRow(
                        Icons.check_circle_outline,
                        'Grading',
                        _quote!.hadithGrading!,
                      ),
                    if (_quote!.translationSource != null)
                      _buildMetaRow(
                        Icons.translate,
                        'Translation',
                        _quote!.translationSource!,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Primary Surface Actions
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _previewWallpaper,
                    icon: const Icon(Icons.wallpaper, size: 18),
                    label: const Text('Set as Wallpaper'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _setAsWidgetQuote,
                    icon: const Icon(Icons.widgets_outlined, size: 18),
                    label: const Text('Set as Widget'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Follow Thinker Button
            if (_personality != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _toggleFollowPersonality,
                  icon: Icon(
                    _isFollowingPersonality
                        ? Icons.check
                        : Icons.person_add_outlined,
                    size: 18,
                  ),
                  label: Text(
                    _isFollowingPersonality
                        ? 'Following ${_personality!.name}'
                        : 'Follow ${_personality!.name}',
                  ),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
