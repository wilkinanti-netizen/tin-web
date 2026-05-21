import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';
import 'package:tincars/features/trips/domain/services/stripe_service.dart';


class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final currencyFormat = NumberFormat.currency(
      symbol: r'$',
      decimalDigits: 2,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Billetera',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null)
            return const Center(child: Text('Usuario no encontrado'));

          return RefreshIndicator(
            onRefresh: () => ref.refresh(userProfileProvider.future),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Balance Card
                  PremiumGlassContainer(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Saldo disponible',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currencyFormat.format(user.walletBalance),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () =>
                                  _showAddFundsDialog(context, ref),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Recargar Saldo',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Text(
                    'Métodos de pago',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentMethodTile(
                    icon: Icons.credit_card,
                    label: 'Tarjeta de Crédito/Débito',
                    trailing: '**** 1234',
                  ),
                  _buildPaymentMethodTile(
                    icon: Icons.money,
                    label: 'Efectivo',
                    trailing: 'Predeterminado',
                    isDefault: true,
                  ),

                  const SizedBox(height: 32),
                  const Text(
                    'Actividad reciente',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ref.watch(walletTransactionsProvider).when(
                    data: (transactions) {
                      if (transactions.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Column(
                              children: [
                                Icon(Icons.history, size: 48, color: Colors.grey[350]),
                                const SizedBox(height: 8),
                                Text(
                                  'No hay transacciones recientes',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: transactions.length,
                        separatorBuilder: (context, index) => Divider(color: Colors.grey[200]),
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          final isPositive = tx.amount > 0;
                          
                          Color iconColor;
                          Color iconBgColor;
                          IconData iconData;
                          Color amountColor = isPositive ? Colors.green.shade700 : Colors.black;

                          switch (tx.type) {
                            case 'topup':
                              iconData = Icons.add_circle_outline;
                              iconColor = Colors.green.shade700;
                              iconBgColor = Colors.green.shade50;
                              break;
                            case 'refund':
                              iconData = Icons.monetization_on_outlined;
                              iconColor = Colors.green.shade700;
                              iconBgColor = Colors.green.shade50;
                              break;
                            case 'payout':
                              iconData = Icons.account_balance_outlined;
                              iconColor = Colors.red.shade700;
                              iconBgColor = Colors.red.shade50;
                              amountColor = Colors.red.shade700;
                              break;
                            case 'commission':
                              iconData = Icons.percent_outlined;
                              iconColor = Colors.orange.shade700;
                              iconBgColor = Colors.orange.shade50;
                              break;
                            case 'payment':
                              iconData = Icons.payment_outlined;
                              iconColor = Colors.grey.shade700;
                              iconBgColor = Colors.grey.shade100;
                              break;
                            case 'trip_payment':
                              iconData = Icons.directions_car_outlined;
                              iconColor = Colors.green.shade700;
                              iconBgColor = Colors.green.shade50;
                              break;
                            default:
                              iconData = isPositive ? Icons.arrow_upward : Icons.arrow_downward;
                              iconColor = isPositive ? Colors.green.shade700 : Colors.grey.shade700;
                              iconBgColor = isPositive ? Colors.green.shade50 : Colors.grey.shade100;
                          }

                          final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(tx.timestamp);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: iconBgColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(iconData, color: iconColor, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.description,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dateStr,
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${isPositive ? '+' : ''}${currencyFormat.format(tx.amount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: amountColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, stack) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'Error cargando transacciones: $err',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildPaymentMethodTile({
    required IconData icon,
    required String label,
    required String trailing,
    bool isDefault = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.black),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: Text(
          trailing,
          style: TextStyle(
            color: isDefault ? Colors.green : Colors.grey,
            fontSize: 12,
            fontWeight: isDefault ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _showAddFundsDialog(BuildContext context, WidgetRef ref) {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          bool isProcessing = false;

          return AlertDialog(
            title: const Text('Recargar Saldo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Selecciona un monto rápido:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [20, 50, 100].map((val) => 
                    InkWell(
                      onTap: isProcessing ? null : () {
                        amountController.text = val.toString();
                        setModalState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: amountController.text == val.toString() ? Colors.black : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '\$$val',
                          style: TextStyle(
                            color: amountController.text == val.toString() ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    )
                  ).toList(),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  enabled: !isProcessing,
                  decoration: const InputDecoration(
                    hintText: 'U otro monto (Mín. \$20)',
                    prefixText: r'$ ',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: isProcessing
                    ? null
                    : () async {
                        final amount =
                            double.tryParse(amountController.text) ?? 0;
                        if (amount < 20.0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'El monto mínimo de recarga es \$20.00 USD',
                              ),
                            ),
                          );
                          return;
                        }

                        setModalState(() => isProcessing = true);

                        try {
                          final user = ref.read(userProfileProvider).value;
                          if (user != null) {
                            // 1. Inicializar PaymentSheet (Stripe Real)
                            await StripeService.instance.initPaymentSheet(
                              user.id,
                              amount,
                              'usd',
                            );

                            // 2. Presentar pasarela de pago
                            await StripeService.instance.displayPaymentSheet();

                            // 3. Si el pago fue exitoso, actualizar saldo en DB
                            await ref
                                .read(profileRepositoryProvider)
                                .updateWalletBalance(
                                  user.id,
                                  amount,
                                  isIncrement: true,
                                  type: 'topup',
                                  description: 'Recarga de saldo por tarjeta',
                                );

                            ref.invalidate(userProfileProvider);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '¡Éxito! \$ ${amount.toStringAsFixed(2)} recargados con éxito',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              Navigator.pop(context);
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al recargar: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (context.mounted) {
                            setModalState(() => isProcessing = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Recargar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
