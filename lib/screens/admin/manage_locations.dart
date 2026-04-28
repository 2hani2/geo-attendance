import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ManageLocations extends StatefulWidget {
  const ManageLocations({super.key});

  @override
  State<ManageLocations> createState() => _ManageLocationsState();
}

class _ManageLocationsState extends State<ManageLocations> {
  final _nameController = TextEditingController();
  final _radiusController = TextEditingController(text: '200');
  final _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  LatLng _selectedLocation = const LatLng(13.3474, 74.7929);
  bool _locationPicked = false;
  final MapController _mapController = MapController();

  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5');
      final response = await http.get(url, headers: {
        'User-Agent': 'geo_attendance_app',
      });
      if (response.statusCode == 200) {
        setState(() {
          _searchResults = jsonDecode(response.body);
          _isSearching = false;
        });
      } else {
        setState(() => _isSearching = false);
      }
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _addLocation() async {
    if (_nameController.text.isEmpty || !_locationPicked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a name and pick a location on the map'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    await _firestore.collection('locations').add({
      'name': _nameController.text.trim(),
      'latitude': _selectedLocation.latitude,
      'longitude': _selectedLocation.longitude,
      'radiusMeters': double.tryParse(_radiusController.text.trim()) ?? 200,
      'createdAt': Timestamp.now(),
    });

    _nameController.clear();
    _radiusController.text = '200';
    setState(() {
      _isLoading = false;
      _locationPicked = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteLocation(String docId) async {
    await _firestore.collection('locations').doc(docId).delete();
  }

  void _openMapPicker() {
    LatLng tempSelected = _selectedLocation;
    _searchController.clear();
    _searchResults = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.92,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pick Location',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search for a place...',
                            hintStyle: const TextStyle(color: Colors.white38),
                            prefixIcon: const Icon(Icons.search,
                                color: Color(0xFF4FC3F7)),
                            suffixIcon: _isSearching
                                ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF4FC3F7),
                                ),
                              ),
                            )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFF16213E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) async {
                            await _searchLocation(val);
                            setModalState(() {});
                          },
                        ),

                        // Search results
                        if (_searchResults.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16213E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final result = _searchResults[index];
                                return ListTile(
                                  leading: const Icon(Icons.location_on,
                                      color: Color(0xFF4FC3F7), size: 20),
                                  title: Text(
                                    result['display_name'],
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    final lat = double.parse(result['lat']);
                                    final lng = double.parse(result['lon']);
                                    setModalState(() {
                                      tempSelected = LatLng(lat, lng);
                                      _searchResults = [];
                                      _searchController.clear();
                                    });
                                    _mapController.move(tempSelected, 16);
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'Lat: ${tempSelected.latitude.toStringAsFixed(5)}, Lng: ${tempSelected.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                        color: Color(0xFF4FC3F7), fontSize: 12),
                  ),
                  const SizedBox(height: 8),

                  // Map
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: tempSelected,
                            initialZoom: 16,
                            onTap: (tapPosition, point) {
                              setModalState(() => tempSelected = point);
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.venisa.geo_attendance',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: tempSelected,
                                  width: 50,
                                  height: 50,
                                  child: const Icon(
                                    Icons.location_pin,
                                    color: Colors.red,
                                    size: 50,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Confirm button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedLocation = tempSelected;
                            _locationPicked = true;
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4FC3F7),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Confirm Location',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Manage Locations',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add New Location',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const SizedBox(height: 16),

            // Name field
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Location Name (e.g. MIT Manipal Main Gate)',
                labelStyle: const TextStyle(color: Colors.white54),
                prefixIcon:
                const Icon(Icons.label, color: Color(0xFF81C784)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF81C784)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Map picker button
            GestureDetector(
              onTap: _openMapPicker,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _locationPicked
                        ? const Color(0xFF81C784)
                        : Colors.white24,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.map,
                      color: _locationPicked
                          ? const Color(0xFF81C784)
                          : Colors.white38,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _locationPicked
                            ? 'Lat: ${_selectedLocation.latitude.toStringAsFixed(5)}, Lng: ${_selectedLocation.longitude.toStringAsFixed(5)}'
                            : 'Tap to search or pick on map',
                        style: TextStyle(
                          color: _locationPicked
                              ? const Color(0xFF81C784)
                              : Colors.white38,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.white38, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Radius field
            TextField(
              controller: _radiusController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Geo-fence Radius (metres)',
                labelStyle: const TextStyle(color: Colors.white54),
                prefixIcon:
                const Icon(Icons.radar, color: Color(0xFF81C784)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF81C784)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Add button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF81C784),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _isLoading ? 'Saving...' : 'Add Location',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 32),

            const Text('Saved Locations',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const SizedBox(height: 16),

            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('locations').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No locations added yet',
                        style: TextStyle(color: Colors.white38)),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16213E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF81C784)
                                .withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: Color(0xFF81C784)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['name'],
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    'Lat: ${(data['latitude'] as num).toStringAsFixed(5)}, Lng: ${(data['longitude'] as num).toStringAsFixed(5)}',
                                    style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12)),
                                Text('Radius: ${data['radiusMeters']}m',
                                    style: const TextStyle(
                                        color: Color(0xFF81C784),
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteLocation(doc.id),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}