import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tincars/features/home/presentation/providers/user_mode_provider.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(userModeProvider);
    final isPassenger = currentMode == UserMode.passenger;
    final userProfileAsync = ref.watch(userProfileProvider);
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.black),
            currentAccountPicture: userProfileAsync.when(
              data: (profile) {
                final avatarUrl =
                    profile?.avatarUrl ?? user?.photoURL;
                final mapEmoji = profile?.mapEmoji;

                return Stack(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white,
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null && mapEmoji != null
                          ? Text(mapEmoji, style: const TextStyle(fontSize: 32))
                          : (avatarUrl == null
                                ? const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Image(
                                      image: AssetImage(
                                        'assets/logo/tlogo.jpeg',
                                      ),
                                      fit: BoxFit.contain,
                                    ),
                                  )
                                : null),
                    ),
                    if (avatarUrl != null && mapEmoji != null)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            mapEmoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const CircleAvatar(
                backgroundColor: Colors.white,
                child: CircularProgressIndicator(),
              ),
              error: (_, __) => const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.error),
              ),
            ),
            accountName: Text(
              userProfileAsync.value?.fullName ??
                  user?.displayName ??
                  'Usuario',
            ),
            accountEmail: Text(user?.email ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Inicio'),
            onTap: () {
              context.pop();
              context.go('/home');
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Mis viajes'),
            onTap: () {
              context.pop();
              context.push('/trips');
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_activity),
            title: const Text('Actividad'),
            onTap: () {
              context.pop();
              context.push('/activity');
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Configuración'),
            onTap: () {
              context.pop();
              context.push('/profile');
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              isPassenger ? Icons.drive_eta : Icons.person_pin_circle,
            ),
            title: Text(
              isPassenger ? 'Cambiar a Conductor' : 'Cambiar a Pasajero',
            ),
            onTap: () {
              ref.read(userModeProvider.notifier).toggleMode();
              context.pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Cambiado a modo ${isPassenger ? 'Conductor' : 'Pasajero'}',
                  ),
                  backgroundColor: Colors.black,
                ),
              );
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              context.go('/login');
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
