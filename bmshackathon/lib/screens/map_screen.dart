import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng _center = const LatLng(10.8505, 76.2711); // Fallback Kerala coords
  bool _loading = true;
  bool _serviceEnabled = false;
  loc.PermissionStatus _permissionGranted = loc.PermissionStatus.denied;
  final loc.Location _location = loc.Location();
  List<_Facility> _facilities = const [];

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      _serviceEnabled = await _location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await _location.requestService();
      }
      _permissionGranted = await _location.hasPermission();
      if (_permissionGranted == loc.PermissionStatus.denied) {
        _permissionGranted = await _location.requestPermission();
      }
      if (_serviceEnabled &&
          (_permissionGranted == loc.PermissionStatus.granted ||
              _permissionGranted == loc.PermissionStatus.grantedLimited)) {
        final data = await _location.getLocation();
        if (data.latitude != null && data.longitude != null) {
          _center = LatLng(data.latitude!, data.longitude!);
        }
      }
    } catch (_) {
      // keep fallback center
    } finally {
      _facilities = _exampleFacilities(_center);
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Facility> _exampleFacilities(LatLng c) {
    // Simple nearby offsets for demo markers
    return [
      _Facility(
        name: 'City Care Clinic',
        address: '12 MG Road, Near Metro',
        position: LatLng(c.latitude + 0.01, c.longitude + 0.012),
      ),
      _Facility(
        name: 'Green Valley Hospital',
        address: '45 Ring Road, Sector 7',
        position: LatLng(c.latitude - 0.008, c.longitude + 0.006),
      ),
      _Facility(
        name: 'Sunrise Health Center',
        address: '3rd Cross, Market Area',
        position: LatLng(c.latitude + 0.004, c.longitude - 0.01),
      ),
    ];
  }

  void _centerOnUser() {
    _mapController.move(_center, 14);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Health Facilities')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.bmshackathon',
                ),
                MarkerLayer(
                  markers: [
                    // User marker (blue)
                    Marker(
                      point: _center,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.my_location, color: Colors.blue, size: 32),
                    ),
                    // Facilities (red) clickable
                    ..._facilities.map((f) => Marker(
                          point: f.position,
                          width: 44,
                          height: 44,
                          child: GestureDetector(
                            onTap: () => _showFacility(context, f),
                            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                          ),
                        )),
                  ],
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _centerOnUser,
        icon: const Icon(Icons.my_location),
        label: const Text('Center on My Location'),
      ),
    );
  }

  Future<void> _showFacility(BuildContext context, _Facility f) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(f.name),
        content: Text(f.address),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _Facility {
  final String name;
  final String address;
  final LatLng position;
  const _Facility({required this.name, required this.address, required this.position});
}
