import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lafz/app/router.dart';
import 'package:lafz/app/theme.dart';
import 'package:lafz/core/constants/app_constants.dart';
import 'package:lafz/core/providers/providers.dart';

class LafzApp extends ConsumerWidget {
  const LafzApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final appLanguage = ref.watch(appLanguageProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: LafzTheme.lightTheme(),
      darkTheme: LafzTheme.darkTheme(),
      themeMode: themeMode,
      locale: Locale(appLanguage.code),
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
        Locale('ur'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
