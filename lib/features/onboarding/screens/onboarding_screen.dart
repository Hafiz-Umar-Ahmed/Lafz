import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lafz/core/constants/app_constants.dart';
import 'package:lafz/core/enums/enums.dart';
import 'package:lafz/core/models/category.dart';
import 'package:lafz/core/models/personality.dart';
import 'package:lafz/core/models/quote.dart';
import 'package:lafz/core/providers/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Selected state
  final Set<int> _selectedCategoryIds = {1, 2, 3};
  final Set<int> _selectedPersonalityIds = {};
  WallpaperPreset _selectedPreset = WallpaperPreset.minimal;
  IntervalHours _selectedWidgetSchedule = IntervalHours.twelve;
  IntervalHours _selectedWallpaperSchedule = IntervalHours.twentyFour;

  List<CategoryModel> _categories = [];
  List<PersonalityModel> _personalities = [];
  QuoteModel? _previewQuote;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final catRepo = ref.read(categoriesRepositoryProvider);
    final pRepo = ref.read(personalitiesRepositoryProvider);
    final qRepo = ref.read(quotesRepositoryProvider);

    final cats = await catRepo.getRootCategories();
    final persons = await pRepo.getAllPublishedPersonalities();
    final quote = await qRepo.getQuoteById(1);

    if (mounted) {
      setState(() {
        _categories = cats;
        _personalities = persons;
        _previewQuote = quote;
        // Default select first few personalities
        _selectedPersonalityIds.addAll(persons.take(4).map((p) => p.id));
      });
    }
  }

  void _nextPage() {
    if (_currentPage < 7) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    // Save initial followed categories and personalities
    final collRepo = ref.read(collectionsRepositoryProvider);
    for (final catId in _selectedCategoryIds) {
      await collRepo.followCollection(catId, CollectionType.category);
    }
    for (final pId in _selectedPersonalityIds) {
      await collRepo.followCollection(pId, CollectionType.personality);
    }

    // Save wallpaper preset
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final currentWallpaperSettings = await settingsRepo.getWallpaperSettings();
    await settingsRepo.updateWallpaperSettings(
      currentWallpaperSettings.copyWith(preset: _selectedPreset),
    );

    // Save rotation schedules
    final rotRepo = ref.read(rotationRepositoryProvider);
    final wSettings = await rotRepo.getRotationSettings(SurfaceType.widget);
    await rotRepo.updateRotationSettings(
      wSettings.copyWith(intervalHours: _selectedWidgetSchedule.hours),
    );

    final wpSettings = await rotRepo.getRotationSettings(SurfaceType.wallpaper);
    await rotRepo.updateRotationSettings(
      wpSettings.copyWith(intervalHours: _selectedWallpaperSchedule.hours),
    );

    ref.read(isOnboardingCompleteProvider.notifier).state = true;

    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation & Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                  Text(
                    'Step ${_currentPage + 1} of 8',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  TextButton(
                    onPressed: _skipOnboarding,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: (_currentPage + 1) / 8.0,
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),

            // Live Quote Preview Banner (PRD Section 5.3: appears after first choice)
            if (_currentPage > 0 && _previewQuote != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Preview: “${_previewQuote!.text}” — ${_previewQuote!.attribution}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Page View
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildWelcomeStep(theme),
                  _buildInterestsStep(theme),
                  _buildPersonalitiesStep(theme),
                  _buildWallpaperStyleStep(theme),
                  _buildWidgetScheduleStep(theme),
                  _buildWallpaperScheduleStep(theme),
                  _buildAddWidgetStep(theme),
                  _buildAutomationStep(theme),
                ],
              ),
            ),

            // Bottom Continue Action
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _nextPage,
                  child: Text(
                    _currentPage == 7 ? 'Get Started' : 'Continue',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              'لفظ',
              style: GoogleFonts.amiri(
                fontSize: 54,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            AppConstants.appName,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            AppConstants.appTagline,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 24),
          const Text(
            'A minimalist companion that turns your chosen wisdom and principles into persistent visual reminders on your home screen and wallpaper.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What wisdom inspires you?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose the categories you want to include in your daily rotation.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategoryIds.contains(cat.id);
                return Card(
                  elevation: 0,
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isSelected ? theme.colorScheme.primary : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  child: CheckboxListTile(
                    title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(cat.description ?? '', style: const TextStyle(fontSize: 12.5)),
                    value: isSelected,
                    activeColor: theme.colorScheme.primary,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedCategoryIds.add(cat.id);
                        } else {
                          _selectedCategoryIds.remove(cat.id);
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalitiesStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Follow thinkers & sources',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Quotes from your followed thinkers will be queued in your rotation.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _personalities.length,
              itemBuilder: (context, index) {
                final p = _personalities[index];
                final isSelected = _selectedPersonalityIds.contains(p.id);
                return Card(
                  elevation: 0,
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isSelected ? theme.colorScheme.primary : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                      child: Text(
                        p.name.substring(0, 1),
                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      p.description ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                        : const Icon(Icons.add_circle_outline, color: Colors.grey),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedPersonalityIds.remove(p.id);
                        } else {
                          _selectedPersonalityIds.add(p.id);
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWallpaperStyleStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose your wallpaper style',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select a preset aesthetic for your lock screen & home screen wallpapers.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              gridDelegate: const DynamicDelegate(),
              itemCount: WallpaperPreset.values.length,
              itemBuilder: (context, index) {
                final preset = WallpaperPreset.values[index];
                final isSelected = _selectedPreset == preset;

                return GestureDetector(
                  onTap: () => setState(() => _selectedPreset = preset),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(preset.defaultBgColor),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '“Wisdom”',
                          style: TextStyle(
                            color: Color(preset.defaultTextColor),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          preset.label,
                          style: TextStyle(
                            color: Color(preset.defaultTextColor).withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(height: 6),
                          Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetScheduleStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Widget refresh schedule',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'How often should your home screen and lock screen widgets rotate quotes?',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ...IntervalHours.values.map((interval) {
            final isSelected = _selectedWidgetSchedule == interval;
            return Card(
              elevation: 0,
              color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isSelected ? theme.colorScheme.primary : const Color(0xFFE2E8F0),
                  width: isSelected ? 1.8 : 1.0,
                ),
              ),
              child: RadioListTile<IntervalHours>(
                title: Text(interval.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Rotates approx. every ${interval.hours} hours'),
                value: interval,
                groupValue: _selectedWidgetSchedule,
                activeColor: theme.colorScheme.primary,
                onChanged: (val) {
                  if (val != null) setState(() => _selectedWidgetSchedule = val);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWallpaperScheduleStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wallpaper rotation schedule',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Wallpapers rotate on their own independent schedule.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ...IntervalHours.values.map((interval) {
            final isSelected = _selectedWallpaperSchedule == interval;
            return Card(
              elevation: 0,
              color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isSelected ? theme.colorScheme.primary : const Color(0xFFE2E8F0),
                  width: isSelected ? 1.8 : 1.0,
                ),
              ),
              child: RadioListTile<IntervalHours>(
                title: Text(interval.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Rotates approx. every ${interval.hours} hours'),
                value: interval,
                groupValue: _selectedWallpaperSchedule,
                activeColor: theme.colorScheme.primary,
                onChanged: (val) {
                  if (val != null) setState(() => _selectedWallpaperSchedule = val);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAddWidgetStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.widgets_outlined, size: 68, color: theme.colorScheme.primary),
          const SizedBox(height: 20),
          const Text(
            'Add Lafz to your home screen',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            '1. Go to your home screen.\n2. Long press on any empty space.\n3. Tap Widgets and search for "Lafz".\n4. Select your preferred widget size (Quote only, or with Attribution).\n5. Place it wherever you desire.',
            style: TextStyle(fontSize: 15, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildAutomationStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, size: 68, color: theme.colorScheme.primary),
          const SizedBox(height: 20),
          const Text(
            'Ambient, quiet delivery',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Lafz runs quietly in the background without needing you to open the app. Your selected wisdom will rotate seamlessly.\n\nYou are in full control — customize collections, schedules, and appearance at any time in Settings.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class DynamicDelegate extends SliverGridDelegateWithFixedCrossAxisCount {
  const DynamicDelegate()
      : super(
          crossAxisCount: 2,
          childAspectRatio: 1.3,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        );
}
