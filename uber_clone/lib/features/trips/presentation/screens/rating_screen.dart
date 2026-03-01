import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/trips/presentation/controllers/rating_controller.dart';

class RatingScreen extends ConsumerStatefulWidget {
  final Trip trip;
  final bool isDriver;
  final String otherUserName;
  final String? otherUserAvatarUrl;

  const RatingScreen({
    super.key,
    required this.trip,
    required this.isDriver,
    required this.otherUserName,
    this.otherUserAvatarUrl,
  });

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen>
    with SingleTickerProviderStateMixin {
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final List<String> _positiveChips = [
    '¡Puntual!',
    'Muy amable',
    'Conducción segura',
    'Auto limpio',
    'Buen camino',
  ];
  final List<String> _negativeChips = [
    'Llegó tarde',
    'Mala actitud',
    'Conducción brusca',
    'Auto sucio',
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

  @override
  void dispose() {
    _commentController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // El usuario que va a ser calificado (si soy conductor, califico al pasajero y viceversa)
  String get _ratedUserId =>
      widget.isDriver ? widget.trip.passengerId : (widget.trip.driverId ?? '');

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
      '[RATING] Enviando: $_selectedRating estrellas para ${widget.isDriver ? "pasajero" : "conductor"} $_ratedUserId',
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
          raterIsDriver: widget.isDriver,
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
                // ── Avatar ──
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: widget.otherUserAvatarUrl != null
                          ? NetworkImage(widget.otherUserAvatarUrl!)
                          : null,
                      child: widget.otherUserAvatarUrl == null
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

                Text(
                  widget.isDriver
                      ? 'Califica al pasajero'
                      : 'Califica tu experiencia',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Tu opinión es muy importante para nosotros',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.4),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // ── Estrellas ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final starIndex = i + 1;
                    return GestureDetector(
                      onTap: () {
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
                ],

                const SizedBox(height: 20),

                // ── Chips rápidos ──
                if (_selectedRating > 0) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _selectedRating >= 4
                          ? 'DESTACADOS'
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
                                : Colors.grey.shade100,
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

                  const SizedBox(height: 20),

                  // ── Comentario ──
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    cursorColor: Colors.black,
                    style: const TextStyle(color: Colors.black, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Escribe un comentario opcional...',
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
                        borderSide: const BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Botón enviar ──
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: ratingState.isSubmitting ? null : _submitRating,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 4,
                      shadowColor: Colors.black26,
                    ),
                    child: ratingState.isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'ENVIAR CALIFICACIÓN',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
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
                            '[RATING] Omitida para viaje ${widget.trip.id}',
                          );
                          Navigator.of(context).popUntil((r) => r.isFirst);
                        },
                  child: Text(
                    'Omitir',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.3),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
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
