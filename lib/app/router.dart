import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lafz/core/models/quote.dart';

import 'package:lafz/features/collections/screens/collection_detail_screen.dart';
import 'package:lafz/features/collections/screens/collections_screen.dart';
import 'package:lafz/features/favorites/screens/favorites_screen.dart';
import 'package:lafz/features/library/screens/category_screen.dart';
import 'package:lafz/features/library/screens/home_screen.dart';
import 'package:lafz/features/library/screens/personality_screen.dart';
import 'package:lafz/features/onboarding/screens/onboarding_screen.dart';
import 'package:lafz/features/quote_detail/screens/quote_detail_screen.dart';
import 'package:lafz/features/search/screens/search_screen.dart';
import 'package:lafz/features/settings/screens/automation_health_screen.dart';
import 'package:lafz/features/settings/screens/settings_screen.dart';
import 'package:lafz/features/settings/screens/widget_settings_screen.dart';
import 'package:lafz/features/wallpapers/screens/wallpaper_screen.dart';
import 'package:lafz/features/hub/hub_action_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/quote/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '1') ?? 1;
          return QuoteDetailScreen(quoteId: id);
        },
      ),
      GoRoute(
        path: '/category/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '1') ?? 1;
          return CategoryScreen(categoryId: id);
        },
      ),
      GoRoute(
        path: '/personality/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '1') ?? 1;
          return PersonalityScreen(personalityId: id);
        },
      ),
      GoRoute(
        path: '/favorites',
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: '/collections',
        builder: (context, state) => const CollectionsScreen(),
      ),
      GoRoute(
        path: '/collection/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '1') ?? 1;
          return CollectionDetailScreen(collectionId: id);
        },
      ),
      GoRoute(
        path: '/wallpapers',
        builder: (context, state) {
          final extra = state.extra;
          final quote = extra is QuoteModel ? extra : null;
          return WallpaperScreen(quote: quote);
        },
      ),

      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/automation',
        builder: (context, state) => const AutomationHealthScreen(),
      ),
      GoRoute(
        path: '/settings/widget',
        builder: (context, state) => const WidgetSettingsScreen(),
      ),
      // Deep-link route for the Quick Rotation home-screen widget
      GoRoute(
        path: '/hub/:action',
        builder: (context, state) =>
            HubActionScreen(action: state.pathParameters['action'] ?? ''),
      ),
    ],
  );
});
