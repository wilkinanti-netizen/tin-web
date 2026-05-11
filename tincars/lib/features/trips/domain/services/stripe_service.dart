import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_functions/cloud_functions.dart';

class StripeService {
  static final StripeService instance = StripeService._();
  StripeService._();

  final _functions = FirebaseFunctions.instance;

  /// Cobra $0 para verificar que la pasarela de pagos funciona.
  /// Usa una Firebase Cloud Function que valida la tarjeta sin cobrar.
  Future<void> setupCardWithZeroAuth(String customerId) async {
    try {
      AppLogger.log(
        '[STRIPE] Solicitando SetupIntent a Firebase para: $customerId',
      );
      final response = await _functions.httpsCallable('stripePayments').call({
        'action': 'create-setup-intent',
        'customerId': customerId,
      });

      final data = response.data as Map<String, dynamic>;
      AppLogger.log('[STRIPE] Respuesta de Cloud Function recibida: $data');

      final setupIntentSecret = data['setupIntent'] as String?;
      final ephemeralKey = data['ephemeralKey'] as String?;
      final stripeCustomerId = data['customer'] as String? ?? customerId;

      if (setupIntentSecret == null) {
        AppLogger.log(
          '[STRIPE] ERROR: setupIntentSecret es nulo. Respuesta: $data',
        );
        throw 'El servidor no devolvió setupIntent. Respuesta: $data';
      }

      AppLogger.log('[STRIPE] Inicializando PaymentSheet...');
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          setupIntentClientSecret: setupIntentSecret,
          customerEphemeralKeySecret: ephemeralKey,
          customerId: stripeCustomerId,
          merchantDisplayName: 'TINS CARS',
          returnURL: 'tincars://stripe-redirect',
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(primary: Colors.black),
          ),
        ),
      );
      AppLogger.log('[STRIPE] PaymentSheet inicializado correctamente');
    } catch (e) {
      if (e is StripeException) {
        AppLogger.error(
          '[STRIPE] Error de Stripe: ${e.error.localizedMessage}',
          error: e,
        );
      } else {
        AppLogger.error(
          '[STRIPE] Error en setupCardWithZeroAuth: $e',
          error: e,
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> initPaymentSheet(
    String customerId,
    double amount,
    String currency,
  ) async {
    try {
      final response = await _functions.httpsCallable('stripePayments').call({
        'action': 'create-payment-intent',
        'amount': amount,
        'currency': currency,
        'customerId': customerId,
      });

      final data = response.data as Map<String, dynamic>;
      final paymentIntentSecret = data['paymentIntent'] as String?;
      final ephemeralKey = data['ephemeralKey'] as String?;
      final stripeCustomerId = data['customer'] as String? ?? customerId;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentSecret,
          customerEphemeralKeySecret: ephemeralKey,
          customerId: stripeCustomerId,
          merchantDisplayName: 'TINS CARS',
          returnURL: 'tincars://stripe-redirect',
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(primary: Colors.black),
          ),
        ),
      );
      return data;
    } catch (e) {
      debugPrint('Error en initPaymentSheet: $e');
      rethrow;
    }
  }

  Future<void> displayPaymentSheet() async {
    try {
      await Stripe.instance.presentPaymentSheet();
      debugPrint('Operación de Stripe completada con éxito');
    } catch (e) {
      if (e is StripeException) {
        debugPrint('Error de Stripe: ${e.error.localizedMessage}');
      } else {
        debugPrint('Error genérico: $e');
      }
      rethrow;
    }
  }
}
