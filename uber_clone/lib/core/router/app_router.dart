import 'package:go_router/go_router.dart';
import 'package:uber_clone/features/auth/presentation/screens/login_screen.dart';
import 'package:uber_clone/features/auth/presentation/screens/register_screen.dart';

final router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    // TODO: Add Home Route
  ],
);
