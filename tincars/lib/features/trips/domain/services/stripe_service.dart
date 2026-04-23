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
    print('[STRIPE] Iniciando verificación de tarjeta (\$0) vía Firebase Cloud Function');
    try {
      final response = await _functions.httpsCallable('stripePayments').call({
        'action': 'create-setup-intent',
        'customerId': customerId,
      });

      final data = response.data as Map<String, dynamic>;
      final setupIntentSecret = data['setupIntent'] as String?;
      final ephemeralKey = data['ephemeralKey'] as String?;
      final stripeCustomerId = data['customer'] as String? ?? customerId;

      if (setupIntentSecret == null) {
        throw 'El servidor no devolvió setupIntent. Respuesta: $data';
      }

      AppLogger.log('[STRIPE] SetupIntent recibido. Mostrando PaymentSheet...');

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          setupIntentClientSecret: setupIntentSecret,
          customerEphemeralKeySecret: ephemeralKey,
          customerId: stripeCustomerId,
          merchantDisplayName: 'TINS CARS',
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(primary: Colors.black),
          ),
        ),
      );
    } catch (e) {
      debugPrint('[STRIPE] Error en setupCardWithZeroAuth: $e');
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

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentSecret,
          customerId: customerId,
          merchantDisplayName: 'TINS CARS',
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
