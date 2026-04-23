import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tincars/core/widgets/permission_disclosure_dialog.dart';

class PermissionService {
  static final PermissionService instance = PermissionService._();
  PermissionService._();

  Future<bool> handleLocationPermission(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // In a real app, maybe show a dialog asking to enable GPS
      return false;
    }

    permission = await Geolocator.checkPermission();

    // If permission is already granted, we are good
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return true;
    }

    // If denied (first time) or deniedForever, we show our disclosure
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PermissionDisclosureDialog(
          title: 'Uso de tu ubicación',
          message:
              'Necesitamos acceder a tu ubicación para mostrarte en el mapa, calcular distancias de viaje y permitir que los conductores te encuentren fácilmente.',
          icon: Icons.location_on_rounded,
          onAccept: () => Navigator.pop(context, true),
          onDecline: () => Navigator.pop(context, false),
        ),
      );

      if (shouldProceed == true) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          return true;
        }
      }
    }

    return false;
  }

  Future<bool> handleBackgroundLocationPermission(BuildContext context) async {
    // This is more specific for drivers
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.always) return true;

    final shouldProceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PermissionDisclosureDialog(
        title: 'Ubicación en segundo plano',
        message:
            'Para recibir solicitudes de viaje incluso cuando la aplicación no está en pantalla activa, necesitamos el permiso de ubicación "Siempre". Esto permite que el sistema te asigne viajes cercanos de forma eficiente.',
        icon: Icons.my_location_rounded,
        onAccept: () => Navigator.pop(context, true),
        onDecline: () => Navigator.pop(context, false),
      ),
    );

    if (shouldProceed == true) {
      // Note: On Android, we should first have whileInUse then ask for Always
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.always) return true;
    }

    return false;
  }

  Future<void> handleNotificationPermission(BuildContext context) async {
    // Note: On newer Android, notifications require explicit permission.
    // For now, let's show a disclosure even if we don't have the plugin yet
    // to explain why they are important.
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PermissionDisclosureDialog(
        title: 'Notificaciones de viaje',
        message:
            'Te enviaremos actualizaciones importantes sobre el estado de tu viaje, la llegada del conductor y promociones exclusivas.',
        icon: Icons.notifications_active_rounded,
        onAccept: () => Navigator.pop(context),
        onDecline: () => Navigator.pop(context),
      ),
    );
  }
}
