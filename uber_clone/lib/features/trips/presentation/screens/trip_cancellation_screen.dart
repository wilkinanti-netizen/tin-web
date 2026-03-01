import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/l10n/app_localizations.dart';

class TripCancellationScreen extends ConsumerStatefulWidget {
  final Trip trip;

  const TripCancellationScreen({super.key, required this.trip});

  @override
  ConsumerState<TripCancellationScreen> createState() =>
      _TripCancellationScreenState();
}

class _TripCancellationScreenState
    extends ConsumerState<TripCancellationScreen> {
  int _currentStep = 0;
  String? _selectedReason;
  final _otherReasonController = TextEditingController();
  // We'll move _reasons to build() to use l10n

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  void _handleCancel() async {
    final l10n = AppLocalizations.of(context)!;
    final reason = _selectedReason == l10n.reasonOther
        ? _otherReasonController.text
        : _selectedReason;

    if (reason == null || reason.isEmpty) return;

    // Perform cancellation
    await ref
        .read(tripControllerProvider.notifier)
        .updateStatus(
          widget.trip.id,
          TripStatus.cancelled,
          cancellationReason: reason,
        );

    if (mounted) {
      // Navigate back to home or a completion state
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final List<String> reasons = [
      l10n.reasonNoLongerNeed,
      l10n.reasonDriverTooFar,
      l10n.reasonErrorRequesting,
      l10n.reasonOrderedAnother,
      l10n.reasonPersonal,
      l10n.reasonOther,
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _currentStep == 0
                ? _buildConfirmationStep(l10n)
                : _buildReasonStep(l10n, reasons),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationStep(AppLocalizations l10n) {
    return Column(
      key: const ValueKey(0),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.warning_rounded, color: Colors.red, size: 80),
        ),
        const SizedBox(height: 40),
        Text(
          l10n.cancelAreYouSure,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.cancelWarning,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        const SizedBox(height: 60),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => setState(() => _currentStep = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              l10n.continueCancellation,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n.keepTrip,
            style: TextStyle(
              color: Colors.grey[800],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReasonStep(AppLocalizations l10n, List<String> reasons) {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.cancelReasonTitle,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.cancelReasonSubtitle,
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: ListView.separated(
            itemCount: reasons.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final reason = reasons[index];
              final isSelected = _selectedReason == reason;
              return ListTile(
                title: Text(reason),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.black)
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                onTap: () => setState(() => _selectedReason = reason),
              );
            },
          ),
        ),
        if (_selectedReason == l10n.reasonOther) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _otherReasonController,
            decoration: InputDecoration(
              hintText: l10n.reasonOtherHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            maxLines: 2,
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _selectedReason != null ? _handleCancel : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              l10n.confirmCancellation,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
