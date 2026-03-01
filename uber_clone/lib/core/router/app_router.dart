import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tincars/features/auth/presentation/screens/login_screen.dart';
import 'package:tincars/features/auth/presentation/screens/register_screen.dart';
import 'package:tincars/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:tincars/features/auth/presentation/screens/terms_screen.dart';
import 'package:tincars/features/home/presentation/screens/main_screen.dart';
import 'package:tincars/features/profile/presentation/screens/profile_screen.dart';
import 'package:tincars/features/trips/presentation/screens/trips_screen.dart';
import 'package:tincars/features/trips/presentation/screens/activity_screen.dart';

final router = GoRouter(
  initialLocation: '/onboarding',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final loc = state.matchedLocation;

    final publicRoutes = [
      '/login',
      '/register',
      '/onboarding',
      '/terms',
      '/privacy',
    ];
    final isPublic = publicRoutes.contains(loc);

    if (session != null) {
      if (loc == '/login' || loc == '/register' || loc == '/onboarding')
        return '/home';
    } else {
      if (!isPublic) return '/login';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(path: '/terms', builder: (context, state) => const TermsScreen()),
    GoRoute(
      path: '/privacy',
      builder: (context, state) => const TermsScreen(isPrivacy: true),
    ),
    GoRoute(path: '/home', builder: (context, state) => const MainScreen()),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(path: '/trips', builder: (context, state) => const TripsScreen()),
    GoRoute(
      path: '/activity',
      builder: (context, state) => const ActivityScreen(),
    ),
  ],
);
