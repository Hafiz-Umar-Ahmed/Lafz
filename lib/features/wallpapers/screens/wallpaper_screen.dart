import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lafz/core/enums/enums.dart';
import 'package:lafz/core/models/quote.dart';
import 'package:lafz/core/models/wallpaper_settings.dart';
import 'package:lafz/core/providers/providers.dart';
import 'package:lafz/core/utils/wallpaper_capture.dart';
import 'package:lafz/features/wallpapers/widgets/wallpaper_renderer_widget.dart';
import 'package:lafz/native/native_bridge.dart';

enum _Panel { style, color, font, text, layout }

/// Background colour choices (ARGB ints). "Template" (null) is added in the UI.
const List<int> _bgPalette = [
  0xFF000000, // black
  0xFF121417, // charcoal
  0xFF0A0F1D, // midnight
  0xFF16251E, // forest
  0xFF1E1A29, // plum
  0xFF2B2118, // espresso
  0xFF1F4037, // deep teal
  0xFF7A1F2B, // maroon
  0xFFF5F1E8, // parchment
  0xFFFFFFFF, // white
];

/// Text colour choices (ARGB ints).
const List<int> _textPalette = [
  0xFFFFFFFF, // white
  0xFFF5F1E8, // parchment
  0xFFE6C77A, // gold
  0xFF9FD8C3, // mint
  0xFFA9C7FF, // sky
  0xFFFFB3B3, // rose
  0xFF2B2118, // espresso
  0xFF000000, // black
];

/// Font choices: (display name, Google Fonts family name). A null family means
/// "use the template's own font". Names must match Google Fonts exactly.
const List<(String, String?)> _fonts = [
  ('Template', null),
  ('Playfair', 'Playfair Display'),
  ('Lora', 'Lora'),
  ('Cinzel', 'Cinzel'),
  ('Cormorant', 'Cormorant Garamond'),
  ('Amiri', 'Amiri'),
  ('Mono', 'Roboto Mono'),
];

/// The ONE wallpaper screen.
///
/// - Pass [quote] to start from a specific quote (e.g. from a quote detail
///   screen). Leave it null to start from the current wallpaper rotation quote.
/// - The preview is the wallpaper itself: no lock-screen or home-screen mock
///   (clock, signal, icons). What you see is exactly what gets applied.
/// - Settings live under the preview (no modal sheet), so every change is
///   visible instantly.
class WallpaperScreen extends ConsumerStatefulWidget {
  final QuoteModel? quote;
  const WallpaperScreen({super.key, this.quote});

  @override
  ConsumerState<WallpaperScreen> createState() => _WallpaperScreenState();
}

class _WallpaperScreenState extends ConsumerState<WallpaperScreen> {
  // Wraps ONLY the clean wallpaper. Nothing else is ever captured.
  final GlobalKey _captureKey = GlobalKey();

  QuoteModel? _quote;
  WallpaperSettingsModel _settings = const WallpaperSettingsModel();
  _Panel _panel = _Panel.style;
  bool _isLoading = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final rotRepo = ref.read(rotationRepositoryProvider);
    final qRepo = ref.read(quotesRepositoryProvider);

    final currentSettings = await settingsRepo.getWallpaperSettings();

    QuoteModel? startQuote = widget.quote;
    if (startQuote == null) {
      final rotSettings = await rotRepo.getRotationSettings(
        SurfaceType.wallpaper,
      );
      final quoteId = rotSettings.currentQuoteId ?? 1;
      startQuote =
          await qRepo.getQuoteById(quoteId) ?? await qRepo.getQuoteById(1);
    }

    if (mounted) {
      setState(() {
        _settings = currentSettings;
        _quote = startQuote;
        _isLoading = false;
      });
    }
  }

  /// Updates the preview instantly. Saves to storage unless [persist] is false
  /// (used while a slider is still being dragged).
  Future<void> _update(
    WallpaperSettingsModel newSettings, {
    bool persist = true,
  }) async {
    setState(() => _settings = newSettings);
    if (persist) {
      await ref
          .read(settingsRepositoryProvider)
          .updateWallpaperSettings(newSettings);
    }
  }

  Future<void> _persistCurrent() async {
    await ref
        .read(settingsRepositoryProvider)
        .updateWallpaperSettings(_settings);
  }

  Future<void> _nextQuote() async {
    final rotRepo = ref.read(rotationRepositoryProvider);
    final newQuote = await rotRepo.rotateNow(SurfaceType.wallpaper);
    if (newQuote != null && mounted) {
      setState(() => _quote = newQuote);
    }
  }

  /// Captures the clean wallpaper at a safe native resolution.
  Future<Uint8List?> _capturePng() =>
      WallpaperCapture.captureBoundary(_captureKey, context);

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _apply() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    _snack('Applying wallpaper...');

    final bytes = await _capturePng();
    if (bytes == null) {
      if (mounted) setState(() => _isBusy = false);
      _snack('Could not render the wallpaper. Please try again.');
      return;
    }

    final success = await NativeBridge.applyWallpaper(
      imageBytes: bytes,
      destination: _settings.destination,
    );

    if (mounted) setState(() => _isBusy = false);
    if (success) {
      _snack('Wallpaper applied to ${_settings.destination.label}!');
    } else {
      _snack(
        'Could not set it directly. Use Export, then set it from Photos/Files.',
      );
    }
  }

  Future<void> _export() async {
    if (_isBusy || _quote == null) return;
    final bytes = await _capturePng();
    if (bytes == null) {
      _snack('Could not render the wallpaper. Please try again.');
      return;
    }
    final xFile = XFile.fromData(
      bytes,
      mimeType: 'image/png',
      name: 'lafz_wallpaper_${_quote!.id}.png',
    );
    await Share.shareXFiles([
      xFile,
    ], text: '“${_quote!.text}” — ${_quote!.attribution}');
  }

  // ---------------------------------------------------------------------------
  // Preview
  // ---------------------------------------------------------------------------

  /// The preview IS the wallpaper: one clean render, which is also what gets
  /// captured when you apply or export.
  Widget _buildPreview(double aspect) {
    final screen = MediaQuery.of(context).size;
    return AspectRatio(
      aspectRatio: aspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        // The wallpaper is laid out at the phone's REAL logical size and then
        // scaled down to fit. So font sizes, margins and line breaks are
        // identical to what gets applied, exported or rotated in the background.
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: screen.width,
            height: screen.height,
            child: RepaintBoundary(
              key: _captureKey,
              child: WallpaperRendererWidget(
                quote: _quote!,
                settings: _settings,
                showLockScreenOverlay: false,
                showHomeScreenOverlay: false,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Inline settings (always visible under the preview)
  // ---------------------------------------------------------------------------

  Widget _buildPanelContent() {
    switch (_panel) {
      case _Panel.style:
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: WallpaperPreset.values.length,
          itemBuilder: (context, index) {
            final preset = WallpaperPreset.values[index];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: ChoiceChip(
                  avatar: CircleAvatar(
                    backgroundColor: Color(preset.defaultBgColor),
                    radius: 8,
                  ),
                  label: Text(
                    preset.label,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  selected: _settings.preset == preset,
                  // Picking a template starts fresh from that template.
                  onSelected: (_) => _update(
                    _settings.copyWith(
                      preset: preset,
                      clearBackgroundColor: true,
                      clearTextColor: true,
                      font: kTemplateFont,
                    ),
                  ),
                ),
              ),
            );
          },
        );

      case _Panel.color:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _colorRow(
              label: 'Background',
              selected: _settings.backgroundColor,
              palette: _bgPalette,
              onPick: (c) => _update(
                c == null
                    ? _settings.copyWith(clearBackgroundColor: true)
                    : _settings.copyWith(backgroundColor: c),
              ),
            ),
            _colorRow(
              label: 'Text',
              selected: _settings.textColor,
              palette: _textPalette,
              onPick: (c) => _update(
                c == null
                    ? _settings.copyWith(clearTextColor: true)
                    : _settings.copyWith(textColor: c),
              ),
            ),
          ],
        );

      case _Panel.font:
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _fonts.length,
          itemBuilder: (context, index) {
            final (name, family) = _fonts[index];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: ChoiceChip(
                  label: Text(
                    name,
                    style: family == null
                        ? const TextStyle(fontSize: 14)
                        : GoogleFonts.getFont(family, fontSize: 14),
                  ),
                  selected: _settings.font == (family ?? kTemplateFont),
                  onSelected: (_) => _update(
                    _settings.copyWith(font: family ?? kTemplateFont),
                  ),
                ),
              ),
            );
          },
        );

      case _Panel.text:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _sliderRow(
              label: 'Size ${_settings.textSize.toInt()}',
              value: _settings.textSize,
              min: 14,
              max: 36,
              divisions: 11,
              onChanged: (v) =>
                  _update(_settings.copyWith(textSize: v), persist: false),
            ),
            _sliderRow(
              label: 'Overlay ${(_settings.overlayOpacity * 100).toInt()}%',
              value: _settings.overlayOpacity,
              min: 0,
              max: 0.8,
              divisions: 8,
              onChanged: (v) => _update(
                _settings.copyWith(overlayOpacity: v),
                persist: false,
              ),
            ),
          ],
        );

      case _Panel.layout:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: WallpaperTextAlignment.values.map((align) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Center(
                      child: ChoiceChip(
                        label: Text(
                          align.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: _settings.textAlignment == align,
                        onSelected: (_) =>
                            _update(_settings.copyWith(textAlignment: align)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Row(
              children: [
                FilterChip(
                  label: const Text('Attribution'),
                  selected: _settings.showAttribution,
                  onSelected: (v) =>
                      _update(_settings.copyWith(showAttribution: v)),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Source'),
                  selected: _settings.showSource,
                  onSelected: (v) => _update(_settings.copyWith(showSource: v)),
                ),
              ],
            ),
          ],
        );
    }
  }

  Widget _colorRow({
    required String label,
    required int? selected,
    required List<int> palette,
    required ValueChanged<int?> onPick,
  }) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // First swatch = back to the template's own colour.
                _swatch(
                  color: null,
                  selected: selected == null,
                  onTap: () => onPick(null),
                ),
                for (final c in palette)
                  _swatch(
                    color: c,
                    selected: selected == c,
                    onTap: () => onPick(c),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _swatch({
    required int? color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color == null ? null : Color(color),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: color == null
            ? Icon(Icons.restart_alt, size: 16, color: scheme.onSurface)
            : null,
      ),
    );
  }

  /// True when the chosen text colour would be hard to read on the chosen
  /// background. Only checked when the user picked a text colour.
  bool _hasLowContrast() {
    final text = _settings.textColor;
    if (text == null) return false;
    final bg = _settings.backgroundColor ?? _settings.preset.defaultBgColor;
    final l1 = Color(text).computeLuminance();
    final l2 = Color(bg).computeLuminance();
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05) < 3.0;
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            onChangeEnd: (_) => _persistCurrent(),
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. What to change
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<_Panel>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _Panel.style,
                    label: Text('Style', style: TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: _Panel.color,
                    label: Text('Color', style: TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: _Panel.font,
                    label: Text('Font', style: TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: _Panel.text,
                    label: Text('Size', style: TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: _Panel.layout,
                    label: Text('Layout', style: TextStyle(fontSize: 12)),
                  ),
                ],
                selected: {_panel},
                onSelectionChanged: (s) => setState(() => _panel = s.first),
              ),
            ),
            SizedBox(height: 104, child: _buildPanelContent()),

            // 2. Where to apply (the ONLY place this is chosen)
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<WallpaperDestination>(
                showSelectedIcon: false,
                segments: WallpaperDestination.values
                    .map(
                      (d) => ButtonSegment(
                        value: d,
                        label: Text(
                          d.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
                selected: {_settings.destination},
                onSelectionChanged: (s) =>
                    _update(_settings.copyWith(destination: s.first)),
              ),
            ),
            const SizedBox(height: 10),

            // 3. Apply
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isBusy ? null : _apply,
                    icon: _isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wallpaper, size: 18),
                    label: Text('Set as ${_settings.destination.label}'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _export,
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: const Text('Export'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_quote == null) {
      return const Scaffold(body: Center(child: Text('No quote available')));
    }

    // Match the real phone's shape so the preview equals the final wallpaper.
    final screenSize = MediaQuery.of(context).size;
    final aspect = screenSize.width / screenSize.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallpaper Studio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: 'Next quote',
            onPressed: _nextQuote,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(child: _buildPreview(aspect)),
            ),
          ),
          if (_hasLowContrast())
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Low contrast: the text may be hard to read on this background.',
                style: TextStyle(fontSize: 11.5, color: Colors.orange),
              ),
            ),
          _buildControls(),
        ],
      ),
    );
  }
}
