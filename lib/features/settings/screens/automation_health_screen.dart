import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lafz/core/enums/enums.dart';
import 'package:lafz/core/models/rotation_settings.dart';
import 'package:lafz/core/providers/providers.dart';
import 'package:lafz/core/utils/rotation_engine.dart';
import 'package:lafz/core/utils/wallpaper_capture.dart';
import 'package:lafz/native/native_bridge.dart';

class AutomationHealthScreen extends ConsumerStatefulWidget {
  const AutomationHealthScreen({super.key});

  @override
  ConsumerState<AutomationHealthScreen> createState() =>
      _AutomationHealthScreenState();
}

class _AutomationHealthScreenState
    extends ConsumerState<AutomationHealthScreen> {
  RotationSettingsModel? _widgetSettings;
  RotationSettingsModel? _wallpaperSettings;
  WallpaperSettingsModel? _wallpaperStyle;
  Map<String, dynamic> _batteryStatus = {};
  bool _isLoading = true;
  SurfaceType? _rotatingSurface;

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    final rotRepo = ref.read(rotationRepositoryProvider);
    final settingsRepo = ref.read(settingsRepositoryProvider);

    final wSettings = await rotRepo.getRotationSettings(SurfaceType.widget);
    final wpSettings = await rotRepo.getRotationSettings(SurfaceType.wallpaper);
    final wpStyle = await settingsRepo.getWallpaperSettings();
    final battery = await NativeBridge.checkAutomationHealth();

    if (mounted) {
      setState(() {
        _widgetSettings = wSettings;
        _wallpaperSettings = wpSettings;
        _wallpaperStyle = wpStyle;
        _batteryStatus = battery;
        _isLoading = false;
      });
    }
  }

  void _snack(String message, {int seconds = 3}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: seconds),
        ),
      );
  }

  Future<void> _testImmediateRotation(SurfaceType surface) async {
    if (_rotatingSurface != null) return;
    setState(() => _rotatingSurface = surface);

    try {
      final rotRepo = ref.read(rotationRepositoryProvider);
      final quote = await rotRepo.rotateNow(surface);

      if (quote == null) {
        _snack('No eligible quote found for ${surface.label}');
        return;
      }

      if (surface == SurfaceType.widget) {
        // No colours passed, so the widget keeps its current colours.
        await NativeBridge.updateWidgetTimeline(
          quoteText: '“${quote.text}”',
          attribution: '— ${quote.attribution}',
        );
        _snack('Widget updated: “${quote.text}” — ${quote.attribution}');
      } else {
        // Use the user's saved wallpaper style (template, font, size, colours,
        // alignment, destination) with the newly selected quote.
        final style = await ref
            .read(settingsRepositoryProvider)
            .getWallpaperSettings();
        if (!mounted) return;
        setState(() => _wallpaperStyle = style);

        final bytes = await WallpaperCapture.renderQuoteToPng(
          context,
          quote,
          style,
        );

        if (bytes == null) {
          _snack(
            'Selected “${quote.text}”, but could not render the wallpaper.',
          );
        } else {
          final ok = await NativeBridge.applyWallpaper(
            imageBytes: bytes,
            destination: style.destination,
          );
          _snack(
            ok
                ? 'Wallpaper applied to ${style.destination.label} (${style.preset.label}): “${quote.text}”'
                : 'Quote selected: “${quote.text}”, but the OS blocked setting the wallpaper.',
          );
        }
      }
    } catch (e) {
      _snack('Rotation failed: $e');
    } finally {
      if (mounted) {
        setState(() => _rotatingSurface = null);
        await _loadHealthData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Automation Health')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isIgnoringBattery =
        _batteryStatus['isIgnoringBatteryOptimizations'] as bool? ?? true;
    final now = DateTime.now();
    final isWidgetOverdue = RotationEngine.isOverdue(
      nextRotation: _widgetSettings?.nextRotationAt,
      now: now,
      intervalHours: _widgetSettings?.intervalHours ?? 12,
    );
    final isWallpaperOverdue = RotationEngine.isOverdue(
      nextRotation: _wallpaperSettings?.nextRotationAt,
      now: now,
      intervalHours: _wallpaperSettings?.intervalHours ?? 24,
    );

    final dateFormat = DateFormat('EEE, MMM d • h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Automation Health'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _rotatingSurface != null ? null : _loadHealthData,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Overall System Status
          Card(
            color: isIgnoringBattery
                ? (isDark ? const Color(0xFF132A1C) : const Color(0xFFE8F5E9))
                : (isDark ? const Color(0xFF332015) : const Color(0xFFFFF3E0)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    isIgnoringBattery
                        ? Icons.check_circle
                        : Icons.warning_amber_rounded,
                    color: isIgnoringBattery ? Colors.green : Colors.orange,
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isIgnoringBattery
                              ? 'Background Delivery Active'
                              : 'Battery Optimization Active',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isIgnoringBattery
                              ? 'Lafz background workers are permitted to update widgets and wallpapers.'
                              : 'Aggressive battery optimization may delay scheduled rotations. We recommend disabling battery restrictions for Lafz.',
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (!isIgnoringBattery) ...[
                          const SizedBox(height: 10),
                          FilledButton.tonal(
                            onPressed: () => NativeBridge.openBatterySettings(),
                            child: const Text('Adjust Battery Settings'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Overdue Warning Card (FR-023)
          if (isWidgetOverdue || isWallpaperOverdue) ...[
            Card(
              color: isDark ? const Color(0xFF3B1E1E) : const Color(0xFFFFEBEE),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Scheduled rotation is overdue. Tap "Test Immediate Rotation" below or check system battery restrictions.',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 3. Widget Surface Status
          const Text(
            'Widget Surface',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHealthRow(
                    'Schedule',
                    _widgetSettings?.scheduleType.label ?? 'Interval',
                  ),
                  _buildHealthRow(
                    'Interval',
                    'Every ${_widgetSettings?.intervalHours ?? 12} hours (approx.)',
                  ),
                  _buildHealthRow(
                    'Last Rotation',
                    _widgetSettings?.lastRotationAt != null
                        ? dateFormat.format(_widgetSettings!.lastRotationAt!)
                        : 'Never',
                  ),
                  _buildHealthRow(
                    'Next Rotation',
                    _widgetSettings?.nextRotationAt != null
                        ? dateFormat.format(_widgetSettings!.nextRotationAt!)
                        : 'Not scheduled',
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _rotatingSurface != null
                          ? null
                          : () => _testImmediateRotation(SurfaceType.widget),
                      icon: _rotatingSurface == SurfaceType.widget
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(
                        _rotatingSurface == SurfaceType.widget
                            ? 'Updating Widget...'
                            : 'Test Immediate Widget Rotation',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 4. Wallpaper Surface Status
          const Text(
            'Wallpaper Surface',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHealthRow(
                    'Schedule',
                    _wallpaperSettings?.scheduleType.label ?? 'Interval',
                  ),
                  _buildHealthRow(
                    'Interval',
                    'Every ${_wallpaperSettings?.intervalHours ?? 24} hours (approx.)',
                  ),
                  _buildHealthRow(
                    'Last Rotation',
                    _wallpaperSettings?.lastRotationAt != null
                        ? dateFormat.format(_wallpaperSettings!.lastRotationAt!)
                        : 'Never',
                  ),
                  _buildHealthRow(
                    'Next Rotation',
                    _wallpaperSettings?.nextRotationAt != null
                        ? dateFormat.format(_wallpaperSettings!.nextRotationAt!)
                        : 'Not scheduled',
                  ),
                  const Divider(height: 20),
                  _buildHealthRow(
                    'Active Template',
                    _wallpaperStyle?.preset.label ?? 'Minimal',
                  ),
                  _buildHealthRow(
                    'Active Font',
                    _wallpaperStyle?.font == kTemplateFont
                        ? 'Template Font (${_wallpaperStyle?.preset.label})'
                        : (_wallpaperStyle?.font ?? 'Template Font'),
                  ),
                  _buildHealthRow(
                    'Font Size',
                    '${_wallpaperStyle?.textSize.toInt() ?? 22} pt',
                  ),
                  _buildHealthRow(
                    'Background',
                    _wallpaperStyle?.backgroundColor != null
                        ? '#${_wallpaperStyle!.backgroundColor!.toRadixString(16).padLeft(8, '0').toUpperCase().substring(2)}'
                        : 'Template Default',
                  ),
                  _buildHealthRow(
                    'Destination',
                    _wallpaperStyle?.destination.label ?? 'Lock Screen',
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        await context.push('/wallpapers');
                        if (mounted) _loadHealthData();
                      },
                      icon: const Icon(Icons.palette_outlined, size: 16),
                      label: const Text('Edit Style in Wallpaper Studio'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _rotatingSurface != null
                          ? null
                          : () => _testImmediateRotation(SurfaceType.wallpaper),
                      icon: _rotatingSurface == SurfaceType.wallpaper
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(
                        _rotatingSurface == SurfaceType.wallpaper
                            ? 'Applying Wallpaper...'
                            : 'Test Immediate Wallpaper Rotation',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 5. Native Android WorkManager Engine Card
        ],
      ),
    );
  }

  Widget _buildHealthRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13.5, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
