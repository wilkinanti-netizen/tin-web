import 'package:flutter/material.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';

class DriverWaitingScreen extends StatelessWidget {
  final String status; // 'pending' or 'rejected'

  const DriverWaitingScreen({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isRejected = status == 'rejected';

    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.black, Color(0xFF1A1A1A)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isRejected
                    ? Colors.redAccent.withOpacity(0.1)
                    : Colors.blueAccent.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isRejected ? Colors.redAccent : Colors.blueAccent,
                  width: 2,
                ),
              ),
              child: Icon(
                isRejected
                    ? Icons.error_outline_rounded
                    : Icons.hourglass_empty_rounded,
                color: isRejected ? Colors.redAccent : Colors.blueAccent,
                size: 60,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              isRejected ? 'Solicitud Rechazada' : 'Documentos en Revisión',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isRejected
                  ? 'Lo sentimos, tu solicitud no cumple con los requisitos. Por favor, contacta a soporte para más detalles.'
                  : 'Hemos recibido tus documentos correctamente. Nuestro equipo los está validando para asegurar la seguridad de la comunidad.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            PremiumGlassContainer(
              padding: const EdgeInsets.all(20),
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
              opacity: 0.05,
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: isRejected ? Colors.redAccent : Colors.blueAccent,
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Tiempo estimado: 24-48 horas hábiles.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
            if (isRejected)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Por ahora solo volver, el usuario podría intentar registrarse de nuevo si borramos driver_data
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'VOLVER AL PERFIL',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              )
            else
              const Text(
                'Te notificaremos en cuanto seas activado.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
