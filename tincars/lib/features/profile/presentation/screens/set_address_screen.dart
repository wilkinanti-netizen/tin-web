import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:tincars/core/services/maps_service.dart';

class SetAddressScreen extends StatefulWidget {
  final String actionType; // 'casa' or 'trabajo'
  final String title;

  const SetAddressScreen({
    super.key,
    required this.actionType,
    required this.title,
  });

  @override
  State<SetAddressScreen> createState() => _SetAddressScreenState();
}

class _SetAddressScreenState extends State<SetAddressScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MapsService _mapsService = MapsService();
  final String _sessionToken = const Uuid().v4();

  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) async {
    if (val.isEmpty) {
      if (mounted) setState(() => _suggestions = []);
      return;
    }

    try {
      final suggestions = await _mapsService.getAutocompleteSuggestions(
        val,
        _sessionToken,
      );
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
        });
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
    }
  }

  void _onLocationSelected(Map<String, dynamic> suggestion) async {
    final placeId = suggestion['place_id'];
    final address =
        suggestion['description'] ??
        suggestion['structured_formatting']['main_text'];

    setState(() => _isLoading = true);

    try {
      final LatLng location = await _mapsService.getPlaceDetails(placeId);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${widget.actionType}_address', address);
      await prefs.setDouble('${widget.actionType}_lat', location.latitude);
      await prefs.setDouble('${widget.actionType}_lng', location.longitude);

      if (mounted) {
        // Return true to indicate success
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving location: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar la dirección.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Buscar dirección...',
                    filled: true,
                    fillColor: Colors.grey[100],
                    prefixIcon: const Icon(Icons.search, color: Colors.black54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.separated(
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.place,
                          color: Colors.blueAccent,
                        ),
                        title: Text(
                          suggestion['structured_formatting']['main_text'] ??
                              '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          suggestion['structured_formatting']['secondary_text'] ??
                              '',
                        ),
                        onTap: () => _onLocationSelected(suggestion),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
