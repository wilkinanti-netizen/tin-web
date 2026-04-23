import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tincars/features/trips/presentation/screens/activity_screen.dart';
import 'package:tincars/features/home/presentation/providers/user_mode_provider.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/features/profile/presentation/screens/driver_service_settings_screen.dart';
import 'package:tincars/features/profile/presentation/screens/account_details_screen.dart';
import 'package:tincars/features/profile/presentation/screens/my_vehicles_screen.dart';
import 'package:tincars/features/profile/presentation/screens/earnings_screen.dart';
import 'package:tincars/features/profile/presentation/screens/driver_waiting_room.dart';
import 'package:tincars/features/profile/presentation/screens/driver_registration_screen.dart';
import 'package:tincars/features/profile/presentation/screens/cards_screen.dart';
import 'package:tincars/core/localization/locale_provider.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'package:tincars/l10n/app_localizations.dart';
import 'package:flutter/services.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploading = false;

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) context.go('/login');
  }

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last;
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final fileName =
          'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      final storageRef = FirebaseStorage.instance.ref().child('avatars/$userId/$fileName');
      
      final uploadTask = storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/$fileExt'),
      );
      
      final snapshot = await uploadTask;
      final avatarUrl = await snapshot.ref.getDownloadURL();

      // Update in profiles table
      await FirebaseFirestore.instance
          .collection('profiles')
          .doc(userId)
          .update({'avatar_url': avatarUrl});

      ref.invalidate(userProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil actualizada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _editName(String currentName) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: currentName);
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Editar Nombre',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Tu nombre completo',
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final newName = controller.text.trim();
                          if (newName.isEmpty || newName == currentName) {
                            Navigator.pop(context);
                            return;
                          }

                          setStateDialog(() => isLoading = true);

                          try {
                            final userId = FirebaseAuth.instance.currentUser!.uid;
                            // Update profiles collection
                            await FirebaseFirestore.instance
                                .collection('profiles')
                                .doc(userId)
                                .update({'full_name': newName});

                            ref.invalidate(userProfileProvider);
                            ref.invalidate(driverProfileProvider);

                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.nameUpdated),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setStateDialog(() => isLoading = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${l10n.errorUpdating}: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editMapEmoji(String? currentEmoji) async {
    final emojis = [
      '🙋‍♂️',
      '🙋‍♀️',
      '🚶‍♂️',
      '🏃',
      '🧑‍💻',
      '😎',
      '👓',
      '🧢',
      '🎒',
      '🎧',
      '🕺',
      '💃',
      '✨',
      '🔥',
      '⚡',
      '💫',
      '🌟',
      '🦄',
      '🍕',
      '☕',
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Avatar de Mapa',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Selecciona cómo te verá el conductor en el mapa',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: emojis.length,
                itemBuilder: (context, index) {
                  final emoji = emojis[index];
                  final isSelected = emoji == currentEmoji;
                  return GestureDetector(
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context);
                      try {
                        final userId = FirebaseAuth.instance.currentUser!.uid;
                        await FirebaseFirestore.instance
                            .collection('profiles')
                            .doc(userId)
                            .update({'map_emoji': emoji});

                        ref.invalidate(userProfileProvider);

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Avatar de mapa actualizado'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blueAccent.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected
                            ? Border.all(color: Colors.blueAccent, width: 2)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(emoji, style: const TextStyle(fontSize: 32)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showReferralDialog(String? code) {
    if (code == null || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Generando tu código... intenta de nuevo en un momento',
          ),
        ),
      );
      ref
          .read(profileRepositoryProvider)
          .ensureReferralCode(FirebaseAuth.instance.currentUser!.uid);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '¡Gana \$5 por referido!',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Comparte tu código con un amigo. Cuando completen su primer viaje, ambos recibirán \$5 de crédito.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Código copiado')));
                Navigator.pop(context);
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copiar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleModeToggle(bool isPassenger) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (isPassenger) {
      try {
        final profileDoc = await FirebaseFirestore.instance
            .collection('profiles')
            .doc(user.uid)
            .get();

        final status = profileDoc.data()?['driver_status'] as String?;
        AppLogger.log('===================================================');
        AppLogger.log('🔍 VERIFICACIÓN DE CONDUCTOR (PERFIL) 🔍');
        AppLogger.log('👤 Usuario ID: ${user.uid}');
        AppLogger.log('📄 Estado en BD (profiles.driver_status): $status');

        if (status == null || status == 'inactive' || status.isEmpty) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DriverRegistrationScreen(),
              ),
            );
          }
          return;
        } else if (status == 'rejected') {
          final verificationDocs = await FirebaseFirestore.instance
              .collection('driver_verifications')
              .where('driver_id', isEqualTo: user.uid)
              .orderBy('created_at', descending: true)
              .limit(1)
              .get();

          final reason = (verificationDocs.docs.isNotEmpty)
              ? (verificationDocs.docs.first.data()['rejection_reason'] as String? ?? 'No se especificó motivo.')
              : 'No se especificó motivo.';
          if (mounted) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text('Solicitud Rechazada'),
                content: Text('Tu solicitud fue rechazada: $reason'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            );
          }
          return;
        } else if (status == 'pending') {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DriverWaitingRoom()),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('Error checking driver status: $e');
        return;
      }
    }

    HapticFeedback.mediumImpact();
    ref.read(isModeTransitioningProvider.notifier).start();
    await Future.delayed(const Duration(milliseconds: 700));
    ref.read(userModeProvider.notifier).toggleMode();
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = ref.watch(userModeProvider);
    final isPassenger = currentMode == UserMode.passenger;
    final user = FirebaseAuth.instance.currentUser;
    final userProfileAsync = ref.watch(userProfileProvider);
    final driverProfileAsync = ref.watch(driverProfileProvider);
    ref.watch(todayDriverStatsProvider);

    final l10n = AppLocalizations.of(context)!;
    final userProfile = userProfileAsync.value;
    String fullName = userProfile?.fullName ?? user?.displayName ?? l10n.user;
    final avatarUrl = userProfile?.avatarUrl;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => ref.read(localeProvider.notifier).toggleLocale(),
            icon: const Icon(Icons.language, color: Colors.black87, size: 20),
            label: Text(
              ref.watch(localeProvider).languageCode.toUpperCase(),
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user != null && !user.emailVerified)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Correo no verificado',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Revisa tu bandeja de entrada para verificar tu cuenta.',
                            style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.6)),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        try {
                          await user.sendEmailVerification();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Correo de verificación enviado')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      child: const Text('Reenviar'),
                    ),
                  ],
                ),
              ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              fullName,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _editName(fullName),
                            icon: const Icon(Icons.edit_rounded, color: Colors.black54, size: 20),
                            tooltip: l10n.editName,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded, size: 16, color: Colors.black87),
                                const SizedBox(width: 4),
                                Text(
                                  userProfile?.averageRating?.toStringAsFixed(1) ?? '5.0',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _uploadAvatar();
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black12,
                          border: Border.all(color: Colors.black12, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                          image: avatarUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(avatarUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: avatarUrl == null
                            ? (userProfile?.mapEmoji != null
                                ? Center(
                                    child: Text(
                                      userProfile!.mapEmoji!,
                                      style: const TextStyle(fontSize: 40),
                                    ),
                                  )
                                : const Icon(Icons.person_rounded, size: 45, color: Colors.black38))
                            : null,
                      ),
                      if (_isUploading)
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            Row(
              children: [
                Expanded(
                  child: _ActionBox(
                    icon: Icons.help_rounded,
                    label: 'Ayuda',
                    onTap: () async {
                      final uri = Uri.parse('whatsapp://send?phone=+14697836010');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No se pudo abrir WhatsApp')),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionBox(
                    icon: Icons.credit_card_rounded,
                    label: 'Pago',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CardsScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionBox(
                    icon: Icons.history_rounded,
                    label: 'Viajes',
                    onTap: () {
                      if (!isPassenger) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EarningsScreen()),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ActivityScreen()),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 36),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPassenger ? Icons.drive_eta_rounded : Icons.person_rounded,
                    color: Colors.black,
                  ),
                ),
                title: Text(
                  isPassenger ? l10n.driveWithTins : l10n.travelWithTins,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                subtitle: Text(
                  isPassenger ? l10n.generateIncome : l10n.requestRideNow,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                trailing: Switch.adaptive(
                  value: !isPassenger,
                  activeColor: Colors.black,
                  onChanged: (_) => _handleModeToggle(isPassenger),
                ),
              ),
            ),

            _MenuSection(
              title: isPassenger ? 'Billetera' : l10n.earnings,
              items: [
                if (isPassenger)
                  _MenuItem(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Mi Saldo',
                    onTap: () => context.push('/wallet'),
                  ),
                if (!isPassenger)
                  _MenuItem(
                    icon: Icons.payments_rounded,
                    label: 'Mis Ganancias',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EarningsScreen()),
                    ),
                  ),
              ],
            ),

            if (!isPassenger) ...[
              const SizedBox(height: 32),
              _MenuSection(
                title: l10n.vehicle,
                items: [
                  _MenuItem(
                    icon: Icons.directions_car_rounded,
                    label: driverProfileAsync.value?.vehicleModel ?? l10n.addVehicle,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyVehiclesScreen()),
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.settings_rounded,
                    label: l10n.serviceSettings,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DriverServiceSettingsScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],

            _MenuSection(
              title: 'Seguridad',
              items: [
                _MenuItem(
                  icon: Icons.shield_outlined,
                  label: 'Centro de Seguridad',
                  onTap: () => context.push('/emergency-contacts'),
                ),
              ],
            ),
            const SizedBox(height: 32),

            _MenuSection(
              title: 'Promociones',
              items: [
                _MenuItem(
                  icon: Icons.card_giftcard_rounded,
                  label: 'Invitar Amigos',
                  onTap: () => _showReferralDialog(userProfile?.referralCode),
                ),
              ],
            ),
            const SizedBox(height: 32),

            if (userProfile?.isAdmin ?? false) ...[
              _MenuSection(
                title: 'Administración',
                items: [
                  _MenuItem(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Panel de Control',
                    onTap: () => context.push('/admin-dashboard'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],

            _MenuSection(
              title: l10n.settings,
              items: [
                _MenuItem(
                  icon: Icons.person_outline_rounded,
                  label: l10n.accountDetails,
                  onTap: () {
                    final user = userProfileAsync.value;
                    if (user != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AccountDetailsScreen(user: user)),
                      );
                    }
                  },
                ),
                if (isPassenger)
                  _MenuItem(
                    icon: Icons.face_rounded,
                    label: 'Avatar de Mapa (Emoji)',
                    trailingText: userProfile?.mapEmoji,
                    onTap: () => _editMapEmoji(userProfile?.mapEmoji),
                  ),
                _MenuItem(
                  icon: Icons.logout_rounded,
                  label: l10n.logout,
                  textColor: Colors.redAccent,
                  onTap: () => _logout(context),
                ),
              ],
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

class _ActionBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionBox({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.black87, size: 28),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.4),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: items.map((item) {
              final isLast = items.last == item;
              return Column(
                children: [
                  item,
                  if (!isLast)
                    const Divider(height: 1, indent: 60, endIndent: 20, color: Colors.black12),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailingText;
  final VoidCallback? onTap;
  final Color textColor;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.trailingText,
    this.onTap,
    this.textColor = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: textColor == Colors.redAccent
              ? Colors.redAccent.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: textColor, size: 22),
      ),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 15),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(trailingText!, style: const TextStyle(fontSize: 18)),
            ),
          if (onTap != null)
            const Icon(Icons.chevron_right_rounded, color: Colors.black26)
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
