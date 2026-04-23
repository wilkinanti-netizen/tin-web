import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/features/profile/domain/models/profiles.dart';
import 'package:tincars/features/profile/domain/models/payout_request.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';

final pendingDriversProvider = FutureProvider<List<AppUser>>((ref) async {
  return ref.read(profileRepositoryProvider).getPendingDrivers();
});

final allPayoutRequestsProvider = FutureProvider<List<PayoutRequest>>((
  ref,
) async {
  return ref
      .read(profileRepositoryProvider)
      .getAllPayoutRequests(status: PayoutStatus.pending);
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Admin Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Conductores'),
              Tab(text: 'Retiros'),
            ],
            labelColor: Colors.black,
            indicatorColor: Colors.black,
          ),
        ),
        body: const TabBarView(
          children: [_PendingDriversList(), _PayoutRequestsList()],
        ),
      ),
    );
  }
}

class _PendingDriversList extends ConsumerWidget {
  const _PendingDriversList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driversAsync = ref.watch(pendingDriversProvider);

    return driversAsync.when(
      data: (drivers) {
        if (drivers.isEmpty) {
          return const Center(child: Text('No hay conductores pendientes'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: drivers.length,
          itemBuilder: (context, index) {
            final driver = drivers[index];
            return PremiumGlassContainer(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driver.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    driver.email,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _updateStatus(
                            context,
                            ref,
                            driver.id,
                            DriverStatus.rejected,
                          ),
                          child: const Text(
                            'Rechazar',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateStatus(
                            context,
                            ref,
                            driver.id,
                            DriverStatus.active,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                          ),
                          child: const Text(
                            'Aprobar',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    String userId,
    DriverStatus status,
  ) async {
    await ref
        .read(profileRepositoryProvider)
        .updateDriverStatus(userId, status);
    ref.invalidate(pendingDriversProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Estado actualizado: ${status.name}')),
      );
    }
  }
}

class _PayoutRequestsList extends ConsumerWidget {
  const _PayoutRequestsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(allPayoutRequestsProvider);

    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(child: Text('No hay retiros pendientes'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return PremiumGlassContainer(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monto: \$${request.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'ID Usuario: ${request.userId}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _updatePayout(
                            context,
                            ref,
                            request.id,
                            PayoutStatus.failed,
                          ),
                          child: const Text(
                            'Marcar Error',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updatePayout(
                            context,
                            ref,
                            request.id,
                            PayoutStatus.completed,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                          ),
                          child: const Text(
                            'Completado',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Future<void> _updatePayout(
    BuildContext context,
    WidgetRef ref,
    String requestId,
    PayoutStatus status,
  ) async {
    await ref
        .read(profileRepositoryProvider)
        .updatePayoutStatus(requestId, status);
    ref.invalidate(allPayoutRequestsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Retiro actualizado: ${status.name}')),
      );
    }
  }
}
