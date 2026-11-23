import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lafz/app/app.dart';
import 'package:lafz/core/providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check onboarding status
  final prefs = await SharedPreferences.getInstance();
  final isCompleted = prefs.getBool('onboarding_completed') ?? false;

  runApp(
    ProviderScope(
      overrides: [
        isOnboardingCompleteProvider.overrideWith((ref) => isCompleted),
      ],
      child: const LafzApp(),
    ),
  );
}
