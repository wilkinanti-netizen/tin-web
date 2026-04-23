import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tincars/features/auth/presentation/screens/login_screen.dart';
import 'package:tincars/features/auth/presentation/screens/register_screen.dart';
import 'package:tincars/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:tincars/features/auth/presentation/screens/terms_screen.dart';
import 'package:tincars/features/home/presentation/screens/main_screen.dart';
import 'package:tincars/features/profile/presentation/screens/profile_screen.dart';
import 'package:tincars/features/trips/presentation/screens/trips_screen.dart';
import 'package:tincars/features/trips/presentation/screens/activity_screen.dart';
import 'package:tincars/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:tincars/features/profile/presentation/screens/wallet_screen.dart';
import 'package:tincars/features/trips/presentation/screens/payment_details_screen.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/profile/presentation/screens/admin_dashboard_screen.dart';
import 'package:tincars/features/profile/presentation/screens/emergency_contacts_screen.dart';
import 'package:tincars/features/profile/presentation/screens/cards_screen.dart';

final router = GoRouter(
  initialLocation: '/onboarding',
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final loc = state.matchedLocation;

    final publicRoutes = [
      '/login',
      '/register',
      '/onboarding',
      '/terms',
      '/privacy',
      '/verify-otp',
    ];
    final isPublic = publicRoutes.contains(loc);

    if (user != null) {
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
    GoRoute(
      path: '/verify-otp',
      builder: (context, state) {
        final phone = state.uri.queryParameters['phone'] ?? '';
        return OtpVerificationScreen(phone: phone);
      },
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
    GoRoute(path: '/wallet', builder: (context, state) => const WalletScreen()),
    GoRoute(
      path: '/admin-dashboard',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/emergency-contacts',
      builder: (context, state) => const EmergencyContactsScreen(),
    ),
    GoRoute(path: '/cards', builder: (context, state) => const CardsScreen()),
    GoRoute(
      path: '/payment-details',
      builder: (context, state) {
        final trip = state.extra as Trip;
        return PaymentDetailsScreen(trip: trip);
      },
    ),
  ],
);
