import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tincars/core/utils/app_logger.dart';

class PricingInjector {
  static Future<void> injectInitialPricing() async {
    final db = FirebaseFirestore.instance;
    final configRef = db.collection('admin_settings').doc('pricing');

    final initialData = {
      'vehicles': {
        'essentials': {
          'name': 'Essentials-Eco',
          'description': 'Disfruta tu viaje en un vehiculo cómodo y agradable para mejorar tu experiencia.',
          'capacity': 4,
          'base': 5.50,
          'baseWeekend': 6.50,
          'tiers': [
            {'upTo': 5.0, 'rate': 2.45},
            {'upTo': 15.0, 'rate': 2.00},
            {'upTo': 999999.0, 'rate': 1.90},
          ],
          'freeWaitMinutes': 3,
          'waitFeePerMinute': 0.40,
        },
        'essentials_xl': {
          'name': 'Essentials XL',
          'description': 'Mas espacio para ti y tu viaje capacidad hasta 6 personas',
          'capacity': 6,
          'base': 6.60,
          'baseWeekend': 7.70,
          'tiers': [
            {'upTo': 5.0, 'rate': 2.70},
            {'upTo': 15.0, 'rate': 2.25},
            {'upTo': 999999.0, 'rate': 2.10},
          ],
          'freeWaitMinutes': 3,
          'waitFeePerMinute': 0.40,
        },
        'executive': {
          'name': 'Executive',
          'description': 'una experiencia de lujo y Seguridad, con conductores experimentados',
          'capacity': 4,
          'base': 9.00,
          'baseWeekend': 10.50,
          'tiers': [
            {'upTo': 5.0, 'rate': 4.80},
            {'upTo': 15.0, 'rate': 3.90},
            {'upTo': 999999.0, 'rate': 3.50},
          ],
          'freeWaitMinutes': 5,
          'waitFeePerMinute': 0.60,
        },
        'signature_lux': {
          'name': 'Signature Lux',
          'description': 'Lujo, comfort y seguridad en un mismo espacio, vehiculos gamma Alta y conductores experimentados',
          'capacity': 6,
          'base': 16.00,
          'baseWeekend': 18.50,
          'tiers': [
            {'upTo': 5.0, 'rate': 6.50},
            {'upTo': 15.0, 'rate': 4.60},
            {'upTo': 999999.0, 'rate': 4.20},
          ],
          'freeWaitMinutes': 5,
          'waitFeePerMinute': 0.60,
        },
      },
      'commission': {
        'enabled': true,
        'percentage': 25.0,
      }
    };

    try {
      AppLogger.log('Inyectando configuración de precios en Firestore...');
      await configRef.set(initialData, SetOptions(merge: true));
      AppLogger.log('Inyección completada con éxito.');
    } catch (e) {
      AppLogger.error('Error al inyectar precios:', error: e);
    }
  }
}
