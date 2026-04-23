import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tincars/features/auth/data/auth_repository.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';
import 'package:google_fonts/google_fonts.dart';

class PendingVerificationScreen extends ConsumerWidget {
  const PendingVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1517048676732-d65bc937f952?q=80&w=2070&auto=format&fit=crop',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.7)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: PremiumGlassContainer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.hourglass_empty_rounded,
                      size: 80,
                      color: Colors.amberAccent,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Cuenta en Revisión',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tus documentos han sido recibidos y están siendo revisados por nuestro equipo de seguridad.',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 24),
                    Text(
                      'Recibirás una notificación cuando tu cuenta sea aprobada y puedas comenzar a conducir.',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.white60,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
