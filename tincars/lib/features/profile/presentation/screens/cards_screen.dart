import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tincars/features/trips/domain/services/stripe_service.dart';
import 'package:tincars/features/profile/domain/models/payout_method.dart';
import 'package:tincars/features/profile/domain/models/payout_request.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:uuid/uuid.dart';

// Provider para las tarjetas guardadas en Firestore
final savedCardsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return [];
  AppLogger.log('[CARDS] Cargando tarjetas para user: ${user.uid}');
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('payment_methods')
        .where('user_id', isEqualTo: user.uid)
        .orderBy('created_at', descending: true)
        .get();
    
    return snapshot.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
    }).toList();
  } catch (e) {
    AppLogger.log('[CARDS] Error cargando tarjetas: $e');
    return [];
  }
});

class CardsScreen extends ConsumerStatefulWidget {
  const CardsScreen({super.key});

  @override
  ConsumerState<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends ConsumerState<CardsScreen> {
  bool _isSaving = false;

  /// Flujo completo: llama al servidor real → crea SetupIntent ($0) →
  /// abre PaymentSheet de Stripe → guarda en Firestore.
  /// Esto verifica la pasarela de extremo a extremo sin cobrar nada.
  Future<void> _addCardViaGateway() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    AppLogger.log('[CARDS] Iniciando flujo de agregar tarjeta via pasarela...');

    try {
      // 1. Servidor crea SetupIntent → sin cobro
      await StripeService.instance.setupCardWithZeroAuth(user.uid);

      // 2. PaymentSheet nativo de Stripe
      await StripeService.instance.displayPaymentSheet();

      AppLogger.log('[CARDS] ✅ Gateway verificado, tarjeta agregada');

      // 3. Registrar en Firestore
      await FirebaseFirestore.instance.collection('payment_methods').add({
        'user_id': user.uid,
        'brand': 'stripe',
        'last4': '****',
        'created_at': FieldValue.serverTimestamp(),
        'stripe_token': 'setup_intent_verified',
      });

      ref.invalidate(savedCardsProvider);

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Pasarela verificada — tarjeta agregada'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } on StripeException catch (e) {
      AppLogger.log('[CARDS] Stripe error: ${e.error.localizedMessage}');
      if (e.error.code == FailureCode.Canceled) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }
      _showError('Stripe: ${e.error.localizedMessage ?? e.toString()}');
    } catch (e) {
      AppLogger.log('[CARDS] Error: $e');
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $message'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _deleteCard(String id) async {
    AppLogger.log('[CARDS] Eliminando tarjeta $id');
    await FirebaseFirestore.instance
        .collection('payment_methods')
        .doc(id)
        .delete();
    ref.invalidate(savedCardsProvider);
  }

  Future<void> _requestWithdrawal(PayoutMethod method) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    if (user.walletBalance < 10.0) {
      _showError('El monto mínimo para retiro es 10.00 USD');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final request = PayoutRequest(
        id: const Uuid().v4(),
        userId: user.id,
        payoutMethodId: method.id,
        amount: user.walletBalance,
        status: PayoutStatus.pending,
        createdAt: DateTime.now(),
      );

      await ref.read(profileRepositoryProvider).requestPayout(request);

      // Restar el saldo de la billetera localmente/DB
      await ref
          .read(profileRepositoryProvider)
          .updateWalletBalance(user.id, user.walletBalance, isIncrement: false);

      ref.invalidate(userProfileProvider);
      ref.invalidate(payoutRequestsProvider);

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Solicitud de retiro enviada correctamente'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      _showError('Error al solicitar retiro: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(savedCardsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'PAGOS Y COBROS',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info banner ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                   Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blue,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Configura tus tarjetas para pagar viajes y tus cuentas bancarias para recibir tus ganancias como conductor.',
                      style: TextStyle(color: Colors.black87, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'TARJETAS DE PAGO',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),

            // ── Lista de tarjetas ──
            Expanded(
              child: cardsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Error: $e',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                data: (cards) {
                  if (cards.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.credit_card_outlined,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Sin tarjetas guardadas',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: cards.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final card = cards[i];
                      final brand = (card['brand'] ?? 'card')
                          .toString()
                          .toUpperCase();
                      final last4 = card['last4'] ?? '****';
                      final expMonth = card['exp_month']?.toString().padLeft(
                        2,
                        '0',
                      );
                      final expYear = card['exp_year']?.toString();
                      final expStr = (expMonth != null && expYear != null)
                          ? '$expMonth/$expYear'
                          : null;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.credit_card_rounded,
                                color: Colors.black87,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$brand •••• $last4',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (expStr != null)
                                    Text(
                                      'Expira $expStr',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  _deleteCard(card['id'].toString()),
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.black45,
                                size: 18,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'CUENTAS PARA COBROS',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: ref
                  .watch(payoutMethodsProvider)
                  .when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    ),
                    error: (e, _) => Center(
                      child: Text(
                        'Error: $e',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    data: (methods) {
                      if (methods.isEmpty) {
                        return Center(
                          child: Text(
                            'Sin cuentas bancarias',
                            style: TextStyle(
                              color: Colors.black45,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: methods.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final m = methods[i];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_rounded,
                                  color: Colors.black54,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.bankName,
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${m.accountHolderName} • ${m.accountNumber}',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _requestWithdrawal(m),
                                  child: const Text(
                                    'RETIRO',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.black26,
                                    size: 20,
                                  ),
                                  onPressed: () => _deletePayoutMethod(m.id),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
            ),

            const SizedBox(height: 16),

            // --- Bottom Buttons ---
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _addCardViaGateway,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'TARJETA',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _showAddPayoutDialog(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'CUENTA BANCO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePayoutMethod(String id) async {
    await ref.read(profileRepositoryProvider).deletePayoutMethod(id);
    ref.invalidate(payoutMethodsProvider);
  }

  void _showAddPayoutDialog() {
    final bankController = TextEditingController();
    final numberController = TextEditingController();
    final holderController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Agregar Cuenta Bancaria',
          style: TextStyle(color: Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField('Banco', bankController),
            const SizedBox(height: 12),
            _buildDialogField('Número de cuenta', numberController),
            const SizedBox(height: 12),
            _buildDialogField('Nombre del titular', holderController),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              final method = PayoutMethod(
                id: '',
                userId: user.uid,
                bankName: bankController.text,
                accountNumber: numberController.text,
                accountHolderName: holderController.text,
                createdAt: DateTime.now(),
              );

              await ref
                  .read(profileRepositoryProvider)
                  .savePayoutMethod(user.uid, method);
              ref.invalidate(payoutMethodsProvider);
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.black12),
        ),
      ),
    );
  }
}
