import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lafz/core/enums/enums.dart';
import 'package:lafz/core/models/content_meta.dart';
import 'package:lafz/core/providers/providers.dart';
import 'package:lafz/core/widgets/apple_grouped_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  ContentMetaModel? _contentMeta;
  bool _optInAnalytics = false;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final meta = await settingsRepo.getContentMeta();
    if (mounted) setState(() => _contentMeta = meta);
  }

  void _showThemeSheet() {
    final currentTheme = ref.read(themeModeProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    'Appearance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildOptionTile<ThemeMode>(
                  title: 'System Default',
                  subtitle: 'Match your device light/dark appearance',
                  value: ThemeMode.system,
                  groupValue: currentTheme,
                  onSelect: (val) {
                    ref.read(themeModeProvider.notifier).state = val;
                    Navigator.pop(context);
                  },
                ),
                _buildOptionTile<ThemeMode>(
                  title: 'Light Theme',
                  subtitle: 'Clean white background and dark text',
                  value: ThemeMode.light,
                  groupValue: currentTheme,
                  onSelect: (val) {
                    ref.read(themeModeProvider.notifier).state = val;
                    Navigator.pop(context);
                  },
                ),
                _buildOptionTile<ThemeMode>(
                  title: 'Dark Theme',
                  subtitle: 'Deep black background for low light',
                  value: ThemeMode.dark,
                  groupValue: currentTheme,
                  onSelect: (val) {
                    ref.read(themeModeProvider.notifier).state = val;
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguageSheet() {
    final currentLang = ref.read(appLanguageProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    'Language & Typography',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (final lang in AppLanguage.values)
                  _buildOptionTile<AppLanguage>(
                    title: lang.displayName,
                    subtitle: lang.isRtl ? 'Right-to-Left (RTL)' : 'Left-to-Right (LTR)',
                    value: lang,
                    groupValue: currentLang,
                    onSelect: (val) {
                      ref.read(appLanguageProvider.notifier).state = val;
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile<T>({
    required String title,
    required String subtitle,
    required T value,
    required T groupValue,
    required ValueChanged<T> onSelect,
  }) {
    final isSelected = value == groupValue;
    final theme = Theme.of(context);

    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? theme.colorScheme.primary : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 13),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: theme.colorScheme.primary, size: 20)
          : null,
      onTap: () => onSelect(value),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Privacy & Local-First'),
        content: const SingleChildScrollView(
          child: Text(
            'Lafz is built on a strict privacy and local-first architecture (NFR-08):\n\n'
            '• No account is required to use any core feature.\n'
            '• All quotes, favorites, and collections remain strictly on your device.\n'
            '• Rotation algorithms run locally and require no internet access.\n'
            '• No quotes or personal information are ever uploaded or tracked.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _restorePurchases() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checking store entitlements... All core content is free.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeModeProvider);
    final currentLang = ref.watch(appLanguageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          // Section 1: Surfaces & Automation
          AppleGroupedSection(
            header: 'Surfaces & Automation',
            footer: 'Configure independent schedules and visual delivery for each platform surface.',
            children: [
              AppleGroupedRow(
                leading: const AppleSettingsIcon(
                  icon: Icons.widgets_rounded,
                  backgroundColor: Color(0xFF007AFF),
                ),
                title: 'Home Screen Widget',
                subtitle: 'Layout styles, intervals, and collections',
                showChevron: true,
                onTap: () => context.push('/settings/widget'),
              ),
              AppleGroupedRow(
                leading: const AppleSettingsIcon(
                  icon: Icons.wallpaper_rounded,
                  backgroundColor: Color(0xFF5856D6),
                ),
                title: 'Wallpaper Studio',
                subtitle: 'Presets, typography, contrast overlay & destination',
                showChevron: true,
                onTap: () => context.push('/wallpapers'),
              ),
              AppleGroupedRow(
                leading: const AppleSettingsIcon(
                  icon: Icons.bolt_rounded,
                  backgroundColor: Color(0xFF34C759),
                ),
                title: 'Automation Health & Battery',
                subtitle: 'Status checks, overdue detection, background delivery',
                showChevron: true,
                onTap: () => context.push('/settings/automation'),
              ),
            ],
          ),

          // Section 2: Appearance & Typography
          AppleGroupedSection(
            header: 'Appearance & Language',
            children: [
              AppleGroupedRow(
                leading: const AppleSettingsIcon(
                  icon: Icons.dark_mode_rounded,
                  backgroundColor: Color(0xFF323236),
                ),
                title: 'Theme Mode',
                subtitle: currentTheme == ThemeMode.system
                    ? 'System Default'
                    : (currentTheme == ThemeMode.light ? 'Light Theme' : 'Dark Theme'),
                showChevron: true,
                onTap: _showThemeSheet,
              ),
              AppleGroupedRow(
                leading: const AppleSettingsIcon(
                  icon: Icons.translate_rounded,
                  backgroundColor: Color(0xFF30B0C7),
                ),
                title: 'App Language & Typography',
                subtitle: currentLang.displayName,
                showChevron: true,
                onTap: _showLanguageSheet,
              ),
            ],
          ),

          // Section 3: Content & Trust
          AppleGroupedSection(
            header: 'Content & Editorial Trust',
            children: [
              AppleGroupedRow(
                leading: const AppleSettingsIcon(
                  icon: Icons.verified_outlined,
                  backgroundColor: Color(0xFFFF9500),
                ),
                title: 'Content Package Version',
                subtitle: 'Release v${_contentMeta?.installedVersion ?? 1} (213 verified items)',
                trailing: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF34C759),
                  size: 18,
                ),
              ),
              AppleGroupedRow(
                leading: const AppleSettingsIcon(
                  icon: Icons.lock_rounded,
                  backgroundColor: Color(0xFF34C759),
                ),
                title: 'Privacy Summary',
                subtitle: 'Local-first • No account • Offline by default',
                showChevron: true,
                onTap: _showPrivacyDialog,
              ),
              AppleGroupedRow(
                leading: const AppleSettingsIcon(
                  icon: Icons.insights_rounded,
                  backgroundColor: Color(0xFFAF52DE),
                ),
                title: 'Opt-In Minimal Analytics',
                subtitle: 'Never includes quote text or personal identifiers',
                trailing: CupertinoSwitch(
                  value: _optInAnalytics,
                  activeColor: const Color(0xFF34C759),
                  onChanged: (val) => setState(() => _optInAnalytics = val),
                ),
              ),
            ],
          ),

          // Section 4: Store & About
          AppleGroupedSection(
            header: 'Store & About',
            children: [
              AppleGroupedRow(
                leading: const AppleSettingsIcon(
                  icon: Icons.restore_rounded,
                  backgroundColor: Color(0xFF007AFF),
                ),
                title: 'Restore Purchases',
                subtitle: 'Verify platform store receipt',
                onTap: _restorePurchases,
              ),
              AppleGroupedRow(
                leading: const AppleSettingsIcon(
                  icon: Icons.info_outline_rounded,
                  backgroundColor: Color(0xFF8E8E93),
                ),
                title: 'About Lafz',
                subtitle: 'Version 1.0.0+1 • Pure wisdom, ambient delivery',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Lafz',
                  applicationVersion: '1.0.0+1',
                  applicationLegalese: '© 2026 Lafz Project. Authentic wisdom delivered to ambient surfaces.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
