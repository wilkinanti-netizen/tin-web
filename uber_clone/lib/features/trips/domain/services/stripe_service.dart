import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StripeService {
  static final StripeService instance = StripeService._();
  StripeService._();

  final _supabase = Supabase.instance.client;

  /// Cobra $0 para verificar que la pasarela de pagos funciona.
  /// Usa una Supabase Edge Function que valida la tarjeta sin cobrar.
  Future<void> setupCardWithZeroAuth(String customerId) async {
    print(
      '[STRIPE] Iniciando verificación de tarjeta (\$0) vía Supabase Edge Function',
    );
    try {
      // 1. Llamar a la Edge Function 'stripe-payments' con la acción 'create-setup-intent'
      final response = await _supabase.functions.invoke(
        'stripe-payments',
        body: {'action': 'create-setup-intent', 'customerId': customerId},
      );

      if (response.status != 200) {
        throw 'Error de Edge Function: ${response.status} - ${response.data}';
      }

      final data = response.data as Map<String, dynamic>;
      final setupIntentSecret = data['setupIntent'] as String?;
      final ephemeralKey = data['ephemeralKey'] as String?;
      final stripeCustomerId = data['customer'] as String? ?? customerId;

      if (setupIntentSecret == null) {
        throw 'El servidor no devolvió setupIntent. Respuesta: ${response.data}';
      }

      AppLogger.log('[STRIPE] SetupIntent recibido. Mostrando PaymentSheet...');

      // 2. Inicializar PaymentSheet con SetupIntent
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

  Future<void> initPaymentSheet(
    String customerId,
    double amount,
    String currency,
  ) async {
    try {
      // 1. Crear el Payment Intent vía Edge Function
      final response = await _supabase.functions.invoke(
        'stripe-payments',
        body: {
          'action': 'create-payment-intent',
          'amount': amount,
          'currency': currency,
          'customerId': customerId,
        },
      );

      if (response.status != 200) {
        throw 'Error de Edge Function: ${response.status} - ${response.data}';
      }

      final data = response.data as Map<String, dynamic>;
      final paymentIntentSecret = data['paymentIntent'] as String?;

      // 2. Inicializar el Payment Sheet
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
