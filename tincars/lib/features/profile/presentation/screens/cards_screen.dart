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

    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
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

  Future<void> _addCardViaGateway() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppLogger.log('[CARDS] Error: Usuario no autenticado al intentar agregar tarjeta');
      return;
    }

    AppLogger.log('[CARDS] Iniciando proceso de agregar tarjeta para: ${user.uid}');
    setState(() => _isSaving = true);
    try {
      AppLogger.log('[CARDS] Llamando a setupCardWithZeroAuth...');
      await StripeService.instance.setupCardWithZeroAuth(user.uid);
      
      AppLogger.log('[CARDS] Mostrando PaymentSheet de Stripe...');
      await StripeService.instance.displayPaymentSheet();

      AppLogger.log('[CARDS] Guardando referencia de tarjeta en Firestore...');
      // Nota: En una implementación real, aquí deberíamos llamar a una función para obtener
      // los detalles de la tarjeta (last4, brand) desde Stripe usando el SetupIntent ID.
      await FirebaseFirestore.instance.collection('payment_methods').add({
        'user_id': user.uid,
        'brand': 'stripe',
        'last4': '****',
        'created_at': FieldValue.serverTimestamp(),
        'stripe_token': 'setup_intent_verified',
      });

      AppLogger.log('[CARDS] Proceso de agregar tarjeta completado con éxito');
      ref.invalidate(savedCardsProvider);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Tarjeta agregada correctamente'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } on StripeException catch (e) {
      AppLogger.error('[CARDS] StripeException: ${e.error.code} - ${e.error.localizedMessage}', error: e);
      if (e.error.code == FailureCode.Canceled) {
        AppLogger.log('[CARDS] Usuario canceló el proceso de Stripe');
      } else {
        _showError('Stripe: ${e.error.localizedMessage ?? e.toString()}');
      }
      if (mounted) setState(() => _isSaving = false);
    } catch (e) {
      AppLogger.error('[CARDS] ERROR CRÍTICO agregando tarjeta: $e', error: e);
      _showError('Error inesperado: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteCard(String id) async {
    await FirebaseFirestore.instance
        .collection('payment_methods')
        .doc(id)
        .delete();
    ref.invalidate(savedCardsProvider);
  }

  Future<void> _showRechargeDialog(BuildContext context, String userId) async {
    final amountController = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Recargar Billetera',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa el monto que deseas recargar a tu saldo de conductor.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                hintText: '0.00',
                prefixText: '\$ ',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context, amount);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('RECARGAR AHORA'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      _processRecharge(userId, result);
    }
  }

  Future<void> _processRecharge(String userId, double amount) async {
    setState(() => _isSaving = true);
    try {
      // 1. Inicializar PaymentSheet con el monto
      await StripeService.instance.initPaymentSheet(userId, amount, 'usd');

      // 2. Presentar PaymentSheet
      await Stripe.instance.presentPaymentSheet();

      // 3. Si tiene éxito, actualizar saldo en Firestore
      await ref.read(profileRepositoryProvider).updateWalletBalance(userId, amount, isIncrement: true);
      
      ref.invalidate(userProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Recarga completada con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (e is StripeException) {
        if (e.error.code != FailureCode.Canceled) {
          _showError('Stripe: ${e.error.localizedMessage}');
        }
      } else {
        _showError('Error al recargar: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _requestWithdrawal(PayoutMethod method) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) {
      AppLogger.log(
        '[WITHDRAWAL] Error: Perfil de usuario no cargado todavía.',
      );
      return;
    }

    AppLogger.log(
      '[WITHDRAWAL] Iniciando retiro para user: ${user.id} a banco: ${method.bankName}',
    );

    if (user.walletBalance < 10.0) {
      AppLogger.log('[WITHDRAWAL] Saldo insuficiente: ${user.walletBalance}');
      _showError('El monto mínimo para retiro es 10.00 USD');
      return;
    }

    final amountController = TextEditingController(
      text: user.walletBalance.toStringAsFixed(2),
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Solicitar Retiro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Cuánto deseas retirar a ${method.bankName}?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monto (USD)',
                prefixText: r'$ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Saldo disponible: \$${user.walletBalance.toStringAsFixed(2)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('RETIRAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) {
      AppLogger.log('[WITHDRAWAL] Retiro cancelado por el usuario');
      return;
    }

    final amount = double.tryParse(amountController.text) ?? 0.0;
    AppLogger.log('[WITHDRAWAL] Monto a retirar: $amount');

    if (amount <= 0 || amount > user.walletBalance) {
      AppLogger.log(
        '[WITHDRAWAL] Monto inválido: $amount (Saldo: ${user.walletBalance})',
      );
      _showError('Monto inválido');
      return;
    }

    if (amount < 10.0) {
      AppLogger.log('[WITHDRAWAL] Monto menor al mínimo: $amount');
      _showError('El monto mínimo es 10.00 USD');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final request = PayoutRequest(
        id: const Uuid().v4(),
        userId: user.id,
        payoutMethodId: method.id,
        amount: amount,
        status: PayoutStatus.pending,
        createdAt: DateTime.now(),
      );

      AppLogger.log(
        '[WITHDRAWAL] Creando documento payout_request: ${request.id}',
      );
      await ref.read(profileRepositoryProvider).requestPayout(request);

      AppLogger.log('[WITHDRAWAL] Actualizando saldo de billetera (descuento)');
      await ref
          .read(profileRepositoryProvider)
          .updateWalletBalance(user.id, amount, isIncrement: false);

      ref.invalidate(userProfileProvider);
      ref.invalidate(payoutRequestsProvider);

      AppLogger.log('[WITHDRAWAL] Retiro solicitado con éxito');
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
      AppLogger.log('[WITHDRAWAL] ERROR CRÍTICO: $e');
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
      body: SingleChildScrollView(
        child: Padding(
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
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.blue,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Configura tus tarjetas para pagar viajes y tus cuentas bancarias para recibir tus ganancias.',
                        style: TextStyle(color: Colors.black87, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Wallet Balance Display ──
              ref.watch(userProfileProvider).when(
                    data: (user) {
                      if (user?.lastMode != 'driver') return const SizedBox.shrink();
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.black, Color(0xFF212121)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'SALDO DISPONIBLE',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _showRechargeDialog(context, user!.id),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.add_circle_outline_rounded, size: 14, color: Colors.black),
                                        SizedBox(width: 4),
                                        Text(
                                          'RECARGAR',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '\$${user?.walletBalance.toStringAsFixed(2) ?? '0.00'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
              const SizedBox(height: 32),

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

              cardsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.black),
                ),
                error: (e, _) => Text(
                  'Error: $e',
                  style: const TextStyle(color: Colors.red),
                ),
                data: (cards) {
                  if (cards.isEmpty) {
                    return _buildEmptyState(
                      Icons.credit_card_outlined,
                      'Sin tarjetas guardadas',
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cards.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final card = cards[i];
                      return _buildCardItem(
                        title:
                            '${(card['brand'] ?? 'TARJETA').toString().toUpperCase()} •••• ${card['last4'] ?? '****'}',
                        subtitle: card['exp_month'] != null
                            ? 'Expira ${card['exp_month']}/${card['exp_year']}'
                            : null,
                        onDelete: () => _deleteCard(card['id'].toString()),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildAddButton(
                label: 'AGREGAR TARJETA',
                onPressed: _isSaving ? null : _addCardViaGateway,
                icon: Icons.add_rounded,
              ),

              const SizedBox(height: 32),
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

              ref
                  .watch(payoutMethodsProvider)
                  .when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    ),
                    error: (e, _) => Text(
                      'Error: $e',
                      style: const TextStyle(color: Colors.red),
                    ),
                    data: (methods) {
                      if (methods.isEmpty) {
                        return _buildEmptyState(
                          Icons.account_balance_rounded,
                          'Sin cuentas bancarias',
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: methods.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final m = methods[i];
                          return _buildPayoutItem(m);
                        },
                      );
                    },
                  ),
              const SizedBox(height: 16),
              _buildAddButton(
                label: 'AGREGAR CUENTA BANCARIA',
                onPressed: () => _showAddPayoutDialog(),
                icon: Icons.add_business_rounded,
                isSecondary: true,
              ),

              const SizedBox(height: 40),
              const Text(
                'HISTORIAL DE RETIROS',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              ref
                  .watch(payoutRequestsProvider)
                  .when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    ),
                    error: (e, _) => Text(
                      'Error: $e',
                      style: const TextStyle(color: Colors.red),
                    ),
                    data: (requests) {
                      if (requests.isEmpty) {
                        return _buildEmptyState(
                          Icons.history_rounded,
                          'Sin retiros previos',
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: requests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final r = requests[i];
                          return _buildHistoryItem(r);
                        },
                      );
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(PayoutRequest r) {
    Color statusColor;
    String statusText;

    switch (r.status) {
      case PayoutStatus.pending:
        statusColor = Colors.orange;
        statusText = 'PENDIENTE';
        break;
      case PayoutStatus.processing:
        statusColor = Colors.blue;
        statusText = 'PROCESANDO';
        break;
      case PayoutStatus.completed:
        statusColor = Colors.green;
        statusText = 'COMPLETADO';
        break;
      case PayoutStatus.failed:
        statusColor = Colors.red;
        statusText = 'FALLIDO';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '\$${r.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}',
                style: const TextStyle(color: Colors.black45, fontSize: 11),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem({
    required String title,
    String? subtitle,
    required VoidCallback onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.credit_card_rounded,
            color: Colors.black87,
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.black54, fontSize: 11),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.black45,
              size: 18,
            ),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutItem(PayoutMethod m) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_rounded, color: Colors.black54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.bankName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${m.accountHolderName} • ${m.accountNumber}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
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
            onPressed: () => _deletePayoutMethod(m.id),
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.black26,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton({
    required String label,
    required VoidCallback? onPressed,
    required IconData icon,
    bool isSecondary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSecondary ? Colors.grey[200] : Colors.black,
          foregroundColor: isSecondary ? Colors.black : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
