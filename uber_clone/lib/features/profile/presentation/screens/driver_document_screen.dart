import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tincars/core/utils/app_logger.dart';

enum DriverDocumentType {
  license,
  vehicleInsurance,
  vehicleRegistration,
  profilePhoto,
}

extension DriverDocumentTypeExtension on DriverDocumentType {
  String get label {
    switch (this) {
      case DriverDocumentType.license:
        return "Driver's License";
      case DriverDocumentType.vehicleInsurance:
        return 'Vehicle Insurance';
      case DriverDocumentType.vehicleRegistration:
        return 'Vehicle Registration';
      case DriverDocumentType.profilePhoto:
        return 'Profile Photo';
    }
  }

  String get description {
    switch (this) {
      case DriverDocumentType.license:
        return 'Front and back of your valid US driver\'s license.';
      case DriverDocumentType.vehicleInsurance:
        return 'Current vehicle insurance card or document.';
      case DriverDocumentType.vehicleRegistration:
        return 'Vehicle registration showing your name and plate.';
      case DriverDocumentType.profilePhoto:
        return 'Clear headshot (no hats, sunglasses).';
    }
  }

  IconData get icon {
    switch (this) {
      case DriverDocumentType.license:
        return Icons.badge_outlined;
      case DriverDocumentType.vehicleInsurance:
        return Icons.shield_outlined;
      case DriverDocumentType.vehicleRegistration:
        return Icons.car_rental;
      case DriverDocumentType.profilePhoto:
        return Icons.person_pin;
    }
  }

  String get bucket => 'driver-docs';
  String storagePath(String userId) => 'drivers/$userId/${name}.jpg';
}

class DriverDocumentUploadScreen extends ConsumerStatefulWidget {
  const DriverDocumentUploadScreen({super.key});

  @override
  ConsumerState<DriverDocumentUploadScreen> createState() =>
      _DriverDocumentUploadScreenState();
}

class _DriverDocumentUploadScreenState
    extends ConsumerState<DriverDocumentUploadScreen> {
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  final Map<DriverDocumentType, String?> _uploadedUrls = {};
  final Map<DriverDocumentType, bool> _isUploading = {};

  Future<void> _pickAndUpload(DriverDocumentType type) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (picked == null) return;

      setState(() => _isUploading[type] = true);

      final userId = _supabase.auth.currentUser!.id;
      final path = type.storagePath(userId);
      final bytes = await File(picked.path).readAsBytes();

      await _supabase.storage
          .from(type.bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final url = _supabase.storage.from(type.bucket).getPublicUrl(path);
      setState(() {
        _uploadedUrls[type] = url;
        _isUploading[type] = false;
      });

      AppLogger.log('Document uploaded: $type → $url');
    } catch (e) {
      setState(() => _isUploading[type] = false);
      AppLogger.error('Upload failed for $type', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitDocuments() async {
    final uploaded = _uploadedUrls.length;
    final required = DriverDocumentType.values.length;
    if (uploaded < required) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please upload all $required documents ($uploaded/$required uploaded).',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase
          .from('driver_data')
          .update({
            'doc_license_url': _uploadedUrls[DriverDocumentType.license],
            'doc_insurance_url':
                _uploadedUrls[DriverDocumentType.vehicleInsurance],
            'doc_registration_url':
                _uploadedUrls[DriverDocumentType.vehicleRegistration],
            'doc_photo_url': _uploadedUrls[DriverDocumentType.profilePhoto],
            'docs_submitted_at': DateTime.now().toIso8601String(),
          })
          .eq('profile_id', userId);

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('✅ Documents Submitted'),
            content: const Text(
              'Your documents are under review. You\'ll be notified within 1-3 business days once approved.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                child: const Text(
                  'Got it',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Submit documents failed', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploaded = _uploadedUrls.length;
    final total = DriverDocumentType.values.length;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Driver Documents',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$uploaded of $total uploaded',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      '${(uploaded / total * 100).round()}%',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: uploaded / total,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation(Colors.black),
                  ),
                ),
              ],
            ),
          ),

          // Document List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Upload clear, legible photos. Blurry or expired documents will be rejected.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),
                ...DriverDocumentType.values.map(
                  (type) => _buildDocumentCard(type),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text(
                      'Submit for Review',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _submitDocuments,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(DriverDocumentType type) {
    final isUploaded = _uploadedUrls.containsKey(type);
    final isLoading = _isUploading[type] == true;
    final url = _uploadedUrls[type];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUploaded ? Colors.green.shade300 : Colors.grey.shade200,
          width: isUploaded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: isLoading ? null : () => _pickAndUpload(type),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon / Thumbnail
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isUploaded
                      ? Colors.green.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : url != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(url, fit: BoxFit.cover),
                      )
                    : Icon(type.icon, color: Colors.grey[500], size: 26),
              ),
              const SizedBox(width: 14),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              // Status
              const SizedBox(width: 8),
              isUploaded
                  ? const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 22,
                    )
                  : Icon(
                      Icons.upload_file_outlined,
                      color: Colors.grey[400],
                      size: 22,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
