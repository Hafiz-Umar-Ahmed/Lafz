import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lafz/core/enums/enums.dart';
import 'package:lafz/core/models/quote.dart';
import 'package:lafz/core/models/rotation_settings.dart';
import 'package:lafz/core/providers/providers.dart';
import 'package:lafz/core/widgets/apple_grouped_card.dart';
import 'package:lafz/features/library/widgets/rotation_hub_widget.dart';
import 'package:lafz/native/native_bridge.dart';

class WidgetSettingsScreen extends ConsumerStatefulWidget {
  const WidgetSettingsScreen({super.key});

  @override
  ConsumerState<WidgetSettingsScreen> createState() =>
      _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends ConsumerState<WidgetSettingsScreen> {
  RotationSettingsModel? _settings;
  QuoteModel? _quote; // The quote the widget is currently showing
  int _layoutStyle =
      1; // 0: quote only, 1: quote + attribution, 2: + category pill
  bool _isLoading = true;
  bool _isRotating = false;

  // Widget background color options
  static const List<_WidgetTheme> _widgetThemes = [
    _WidgetTheme('Dark', Color(0xCC1E232B), Colors.white),
    _WidgetTheme('Charcoal', Color(0xE62D2D2D), Colors.white),
    _WidgetTheme('Midnight Blue', Color(0xE61A237E), Colors.white),
    _WidgetTheme('Forest', Color(0xE61B5E20), Colors.white),
    _WidgetTheme('Burgundy', Color(0xE6880E4F), Colors.white),
    _WidgetTheme('Warm Beige', Color(0xE6F5F0E8), Color(0xFF2D2D2D)),
    _WidgetTheme('Soft White', Color(0xE6FFFFFF), Color(0xFF1E232B)),
    _WidgetTheme('Cream', Color(0xE6FFF8E1), Color(0xFF3E2723)),
    _WidgetTheme('Slate', Color(0xE637474F), Colors.white),
    _WidgetTheme('Teal', Color(0xE6004D40), Colors.white),
  ];

  int _selectedThemeIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final rotRepo = ref.read(rotationRepositoryProvider);
    final qRepo = ref.read(quotesRepositoryProvider);

    final s = await rotRepo.getRotationSettings(SurfaceType.widget);
    final quote =
        await qRepo.getQuoteById(s.currentQuoteId ?? 1) ??
        await qRepo.getQuoteById(1);

    if (!mounted) return;
    setState(() {
      _settings = s;
      _quote = quote;
      _isLoading = false;
    });

    // Make sure the real widget shows the same quote as this preview.
    await _pushToWidget();
  }

  Future<void> _updateSchedule(IntervalHours hours) async {
    if (_settings == null) return;
    final rotRepo = ref.read(rotationRepositoryProvider);
    final updated = _settings!.copyWith(intervalHours: hours.hours);
    await rotRepo.updateRotationSettings(updated);
    setState(() => _settings = updated);
  }

  String _colorToHex(Color c) {
    return '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  /// Sends the CURRENT quote and the chosen colours to the native widget.
  Future<void> _pushToWidget() async {
    final quote = _quote;
    if (quote == null) return;
    final theme = _widgetThemes[_selectedThemeIndex];
    try {
      await NativeBridge.updateWidgetTimeline(
        quoteText: '“${quote.text}”',
        attribution: _layoutStyle == 0 ? '' : '— ${quote.attribution}',
        bgColor: _colorToHex(theme.bgColor),
        textColor: _colorToHex(theme.textColor),
      );
    } catch (_) {
      // Native side unavailable (e.g. tests or unsupported platform).
    }
  }

  Future<void> _applyWidgetTheme(int index) async {
    setState(() => _selectedThemeIndex = index);
    await _pushToWidget();
  }

  Future<void> _changeLayout(int value) async {
    setState(() => _layoutStyle = value);
    await _pushToWidget();
  }

  /// Moves the widget to the next quote from the rotation pool.
  Future<void> _nextQuote() async {
    if (_isRotating) return;
    setState(() => _isRotating = true);
    final rotRepo = ref.read(rotationRepositoryProvider);
    final newQuote = await rotRepo.rotateNow(SurfaceType.widget);
    if (!mounted) return;
    setState(() {
      _isRotating = false;
      if (newQuote != null) _quote = newQuote;
    });
    if (newQuote != null) {
      await _pushToWidget();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other quote available to rotate to.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedWidgetTheme = _widgetThemes[_selectedThemeIndex];

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Widget Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final quote = _quote;
    if (quote == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Widget Settings')),
        body: const Center(child: Text('No quote available')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget Settings'),
        actions: [
          IconButton(
            icon: _isRotating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.shuffle),
            tooltip: 'Next quote',
            onPressed: _isRotating ? null : _nextQuote,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Widget Live Preview Card (shows the real current quote)
          const Text(
            'Widget Appearance Preview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: selectedWidgetTheme.bgColor,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_layoutStyle == 2) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.auto_stories,
                        size: 14,
                        color: selectedWidgetTheme.textColor,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          quote.sourceTitle ?? 'Wisdom',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: selectedWidgetTheme.textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  '“${quote.text}”',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                    color: selectedWidgetTheme.textColor,
                  ),
                ),
                if (_layoutStyle >= 1) ...[
                  const SizedBox(height: 10),
                  Text(
                    '— ${quote.attribution}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: selectedWidgetTheme.textColor.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Widget Background Theme
          const Text(
            'Widget Background',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _widgetThemes.length,
              itemBuilder: (context, index) {
                final wt = _widgetThemes[index];
                final isSelected = index == _selectedThemeIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => _applyWidgetTheme(index),
                    child: Column(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: wt.bgColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.grey.shade400,
                              width: isSelected ? 3 : 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.3),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          wt.name,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Layout Style Selector
          AppleGroupedSection(
            header: 'Layout Style',
            children: [
              AppleGroupedRow(
                title: 'Quote with Attribution & Source',
                subtitle: 'Full view with category/source pill',
                trailing: _layoutStyle == 2
                    ? Icon(Icons.check, color: theme.colorScheme.primary, size: 20)
                    : null,
                onTap: () => _changeLayout(2),
              ),
              AppleGroupedRow(
                title: 'Quote with Attribution',
                subtitle: 'Balanced minimalist layout',
                trailing: _layoutStyle == 1
                    ? Icon(Icons.check, color: theme.colorScheme.primary, size: 20)
                    : null,
                onTap: () => _changeLayout(1),
              ),
              AppleGroupedRow(
                title: 'Quote Text Only',
                subtitle: 'Pure typographic simplicity',
                trailing: _layoutStyle == 0
                    ? Icon(Icons.check, color: theme.colorScheme.primary, size: 20)
                    : null,
                onTap: () => _changeLayout(0),
              ),
            ],
          ),

          // Refresh Interval
          AppleGroupedSection(
            header: 'Refresh Interval',
            footer: 'Intervals are approximate because the operating system manages widget timeline budget and wakeups.',
            children: IntervalHours.values.map((h) {
              final isSelected = _settings?.intervalHours == h.hours;
              return AppleGroupedRow(
                title: h.label,
                trailing: isSelected
                    ? Icon(Icons.check, color: theme.colorScheme.primary, size: 20)
                    : null,
                onTap: () => _updateSchedule(h),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _WidgetTheme {
  final String name;
  final Color bgColor;
  final Color textColor;

  const _WidgetTheme(this.name, this.bgColor, this.textColor);
}
