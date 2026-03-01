import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploading = false;

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
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
      final fileName =
          'avatar_${Supabase.instance.client.auth.currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      // Supabase storage paths
      final filePath =
          '${Supabase.instance.client.auth.currentUser!.id}/$fileName';

      // Upload to Supabase Storage in 'avatars' bucket
      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final avatarUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath);

      // Update in auth metadata
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'avatar_url': avatarUrl}),
      );

      // Update in profiles table
      await Supabase.instance.client
          .from('profiles')
          .update({'avatar_url': avatarUrl})
          .eq('id', Supabase.instance.client.auth.currentUser!.id);

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
                            // Update auth metadata
                            await Supabase.instance.client.auth.updateUser(
                              UserAttributes(data: {'full_name': newName}),
                            );

                            // Update profiles table
                            await Supabase.instance.client
                                .from('profiles')
                                .update({'full_name': newName})
                                .eq(
                                  'id',
                                  Supabase.instance.client.auth.currentUser!.id,
                                );

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

  Future<void> _handleModeToggle(bool isPassenger) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    if (isPassenger) {
      try {
        final profileResponse = await Supabase.instance.client
            .from('profiles')
            .select('driver_status')
            .eq('id', user.id)
            .maybeSingle();

        final status = profileResponse?['driver_status'] as String?;
        AppLogger.log('===================================================');
        AppLogger.log('🔍 VERIFICACIÓN DE CONDUCTOR (PERFIL) 🔍');
        AppLogger.log('👤 Usuario ID: ${user.id}');
        AppLogger.log('📄 Estado en BD (profiles.driver_status): $status');
        if (status == 'active') {
          AppLogger.log(
            '✅ ESTADO: ACEPTADO. Permitiendo acceso al modo conductor.',
          );
        } else if (status == 'pending') {
          print(
            '⏳ ESTADO: PENDIENTE. Bloqueando acceso por falta de aprobación del ADMIN.',
          );
        } else if (status == 'rejected') {
          print(
            '❌ ESTADO: RECHAZADO. Bloqueando acceso (documentos denegados).',
          );
        } else {
          print(
            '⚠️ ESTADO: NO REGISTRADO o INACTIVO. Redirigiendo a pantalla de registro.',
          );
        }
        AppLogger.log('===================================================');

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
          final verificationData = await Supabase.instance.client
              .from('driver_verifications')
              .select('rejection_reason')
              .eq('driver_id', user.id)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          final reason =
              verificationData?['rejection_reason'] as String? ??
              'No se especificó motivo.';
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

    ref.read(isModeTransitioningProvider.notifier).start();
    await Future.delayed(const Duration(milliseconds: 700));
    ref.read(userModeProvider.notifier).toggleMode();
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = ref.watch(userModeProvider);
    final isPassenger = currentMode == UserMode.passenger;
    final user = Supabase.instance.client.auth.currentUser;
    final userProfileAsync = ref.watch(userProfileProvider);
    final driverProfileAsync = ref.watch(driverProfileProvider);
    ref.watch(todayDriverStatsProvider);

    final l10n = AppLocalizations.of(context)!;
    String fullName = l10n.user;
    if (userProfileAsync.value != null &&
        userProfileAsync.value!.fullName.isNotEmpty) {
      fullName = userProfileAsync.value!.fullName;
    } else if (user?.userMetadata?['full_name'] != null) {
      fullName = user!.userMetadata!['full_name'];
    }

    final avatarUrl =
        userProfileAsync.value?.avatarUrl ?? user?.userMetadata?['avatar_url'];

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
            // ── Large Header ──
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
                            icon: const Icon(
                              Icons.edit_rounded,
                              color: Colors.black54,
                              size: 20,
                            ),
                            tooltip: l10n.editName,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: Colors.black87,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  userProfileAsync.value?.averageRating
                                          ?.toStringAsFixed(1) ??
                                      '5.0',
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
                  onTap: _uploadAvatar,
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
                            ? const Icon(
                                Icons.person_rounded,
                                size: 45,
                                color: Colors.black38,
                              )
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
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // ── Main Actions (Grid) ──
            Row(
              children: [
                Expanded(
                  child: _ActionBox(
                    icon: Icons.help_rounded,
                    label: 'Ayuda',
                    onTap: () async {
                      final uri = Uri.parse(
                        'whatsapp://send?phone=+14697836010',
                      );
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No se pudo abrir WhatsApp'),
                            ),
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
                          MaterialPageRoute(
                            builder: (_) => const EarningsScreen(),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ActivityScreen(),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 36),

            // ── Mode Toggle ──
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPassenger
                        ? Icons.drive_eta_rounded
                        : Icons.person_rounded,
                    color: Colors.black,
                  ),
                ),
                title: Text(
                  isPassenger ? l10n.driveWithTins : l10n.travelWithTins,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  isPassenger ? l10n.generateIncome : l10n.requestRideNow,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Switch.adaptive(
                  value: !isPassenger,
                  activeColor: Colors.black,
                  onChanged: (_) => _handleModeToggle(isPassenger),
                ),
              ),
            ),

            const SizedBox(height: 36),

            // ── Sections ──
            if (!isPassenger) ...[
              _MenuSection(
                title: l10n.earnings,
                items: [
                  _MenuItem(
                    icon: Icons.account_balance_wallet_rounded,
                    label: l10n.walletAndPayments,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EarningsScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _MenuSection(
                title: l10n.vehicle,
                items: [
                  _MenuItem(
                    icon: Icons.directions_car_rounded,
                    label:
                        driverProfileAsync.value?.vehicleModel ??
                        l10n.addVehicle,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyVehiclesScreen(),
                      ),
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.settings_rounded,
                    label: l10n.serviceSettings,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DriverServiceSettingsScreen(),
                      ),
                    ),
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
                        MaterialPageRoute(
                          builder: (_) => AccountDetailsScreen(user: user),
                        ),
                      );
                    }
                  },
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

// ── UI Building Blocks ──

class _ActionBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionBox({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
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
                    const Divider(
                      height: 1,
                      indent: 60,
                      endIndent: 20,
                      color: Colors.black12,
                    ),
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
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color textColor;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.trailing,
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
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: textColor,
          fontSize: 15,
        ),
      ),
      trailing:
          trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right_rounded, color: Colors.black26)
              : null),
    );
  }
}
