import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tincars/features/home/presentation/providers/user_mode_provider.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(userModeProvider);
    final isPassenger = currentMode == UserMode.passenger;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.black),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Image(
                  image: AssetImage('assets/logo/tlogo.jpeg'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            accountName: const Text('Wilkin'),
            accountEmail: const Text('user@example.com'),
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
