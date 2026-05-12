import 'package:flutter/services.dart';
import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/trips/presentation/controllers/rating_controller.dart';

/// Pantalla de calificación para el PASAJERO.
/// El pasajero califica al conductor al finalizar el viaje.
class PassengerRatingScreen extends ConsumerStatefulWidget {
  final Trip trip;
  final String driverName;
  final String? driverAvatarUrl;

  const PassengerRatingScreen({
    super.key,
    required this.trip,
    required this.driverName,
    this.driverAvatarUrl,
  });

  @override
  ConsumerState<PassengerRatingScreen> createState() =>
      _PassengerRatingScreenState();
}

class _PassengerRatingScreenState extends ConsumerState<PassengerRatingScreen>
    with SingleTickerProviderStateMixin {
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Chips específicos para evaluar al CONDUCTOR
  final List<String> _positiveChips = [
    '¡Puntual!',
    'Muy amable',
    'Conducción segura',
    'Buen camino',
  ];
  final List<String> _negativeChips = [
    'Llegó tarde',
    'Mala actitud',
    'Conducción brusca',
    'Mal camino',
  ];
  final Set<String> _selectedChips = {};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  double? _selectedTip;
  final TextEditingController _customTipController = TextEditingController();
  bool _isCustomTip = false;

  final List<double> _tipOptions = [1.0, 2.0, 5.0];

  @override
  void dispose() {
    _commentController.dispose();
    _customTipController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // El pasajero califica al conductor
  String get _ratedUserId => widget.trip.driverId ?? '';

  Future<void> _submitRating() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor selecciona una calificación'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    AppLogger.log(
      '[RATING][PASAJERO] Enviando: $_selectedRating estrellas al conductor $_ratedUserId con propina de $_selectedTip',
    );

    final success = await ref
        .read(ratingControllerProvider.notifier)
        .submitRating(
          tripId: widget.trip.id,
          ratedId: _ratedUserId,
          stars: _selectedRating,
          tags: _selectedChips.toList(),
          comment: _commentController.text.trim().isEmpty
              ? null
              : _commentController.text.trim(),
          raterIsDriver: false,
          tipAmount: _selectedTip,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('¡Calificación enviada! Gracias.'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } else if (mounted) {
      final errorMsg =
          ref.read(ratingControllerProvider).error ?? 'Error desconocido';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $errorMsg'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCustomTipDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Propina personalizada'),
        content: TextField(
          controller: _customTipController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: '\$', hintText: '0.00'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(_customTipController.text);
              if (val != null && val > 0) {
                setState(() {
                  _selectedTip = val;
                  _isCustomTip = true;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ratingState = ref.watch(ratingControllerProvider);
    final chips = _selectedRating >= 4 ? _positiveChips : _negativeChips;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                // ── Avatar del conductor ──
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: widget.driverAvatarUrl != null
                          ? NetworkImage(widget.driverAvatarUrl!)
                          : null,
                      child: widget.driverAvatarUrl == null
                          ? const Icon(
                              Icons.person_rounded,
                              color: Colors.grey,
                              size: 36,
                            )
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text(
                  'Califica tu experiencia',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.driverName,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // ── Estrellas ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final starIndex = i + 1;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _selectedRating = starIndex;
                          _selectedChips.clear();
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          starIndex <= _selectedRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: starIndex <= _selectedRating
                              ? Colors.amber
                              : Colors.grey.shade300,
                          size: starIndex <= _selectedRating ? 42 : 36,
                        ),
                      ),
                    );
                  }),
                ),

                if (_selectedRating > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    _getRatingLabel(_selectedRating),
                    style: TextStyle(
                      color: _getRatingColor(_selectedRating),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),

                  // ── Propina ──
                  if (_selectedRating >= 4) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'AÑADIR PROPINA',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.4),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ..._tipOptions.map((tip) {
                          final isSelected =
                              _selectedTip == tip && !_isCustomTip;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _selectedTip = isSelected ? null : tip;
                                    _isCustomTip = false;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.black
                                          : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    '\$$tip',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _showCustomTipDialog();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _isCustomTip
                                      ? Colors.black
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: _isCustomTip
                                        ? Colors.black
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: Text(
                                  _isCustomTip
                                      ? '\$${_selectedTip?.toStringAsFixed(1)}'
                                      : 'Otro',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _isCustomTip
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],

                  // ── Chips rápidos ──
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _selectedRating >= 4
                          ? '¿QUÉ TE GUSTÓ?'
                          : 'OPCIONES DE MEJORA',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: chips.map((chip) {
                      final selected = _selectedChips.contains(chip);
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            if (selected) {
                              _selectedChips.remove(chip);
                            } else {
                              _selectedChips.add(chip);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.black
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: selected
                                  ? Colors.black
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Text(
                            chip,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // ── Comentario ──
                  TextField(
                    controller: _commentController,
                    maxLines: 3,
                    cursorColor: Colors.black,
                    style: const TextStyle(color: Colors.black, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Comentarios adicionales...',
                      hintStyle: TextStyle(
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey.shade100),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.black12),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                // ── Botón enviar ──
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: ratingState.isSubmitting ? null : _submitRating,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: ratingState.isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'ENVIAR',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 14),
                TextButton(
                  onPressed: ratingState.isSubmitting
                      ? null
                      : () {
                          AppLogger.log(
                            '[RATING][PASAJERO] Omitida para viaje ${widget.trip.id}',
                          );
                          Navigator.of(context).popUntil((r) => r.isFirst);
                        },
                  child: Text(
                    'OMITIR',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.3),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Muy malo';
      case 2:
        return 'Malo';
      case 3:
        return 'Regular';
      case 4:
        return 'Bueno';
      case 5:
        return '¡Excelente!';
      default:
        return '';
    }
  }

  Color _getRatingColor(int rating) {
    if (rating >= 4) return Colors.amber;
    if (rating == 3) return Colors.orange;
    return Colors.redAccent;
  }
}
