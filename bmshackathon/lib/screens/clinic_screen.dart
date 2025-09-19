import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../i18n/app_localizations.dart';
import '../services/api_service.dart';

class ClinicScreen extends StatefulWidget {
  const ClinicScreen({super.key});

  @override
  State<ClinicScreen> createState() => _ClinicScreenState();
}

class _ClinicScreenState extends State<ClinicScreen> {
  double? _lat;
  double? _lon;
  String? _error;
  bool _loading = true;
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _services = [];

  double? _distanceKmOf(Clinic c) {
    if (_lat == null || _lon == null || c.lat == null || c.lon == null) return null;
    final d = Geolocator.distanceBetween(
      _lat!,
      _lon!,
      c.lat!,
      c.lon!,
    );
    return d / 1000.0; // meters -> km
  }

  Future<void> _openDirectionsTo(Clinic c) async {
    if (c.lat == null || c.lon == null) {
      await _openNearbyClinics();
      return;
    }
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${c.lat},${c.lon}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() {
          _error = 'Location services are disabled';
          _loading = false;
        });
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() {
          _error = 'Location permission denied';
          _loading = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      _lat = pos.latitude;
      _lon = pos.longitude;
      await _loadNearby();
      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to get location: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadNearby() async {
    if (_lat == null || _lon == null) return;
    try {
      final data = await _api.servicesNearby(
        lat: _lat!,
        lon: _lon!,
        radiusKm: 15,
        limit: 20,
      );
      setState(() {
        _services = data;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load clinics: $e';
      });
    }
  }

  Future<void> _openNearbyClinics() async {
    final uri = (_lat == null || _lon == null)
        ? Uri.parse('https://www.google.com/maps/search/clinics/')
        : Uri.parse('https://www.google.com/maps/search/clinics/@${_lat},${_lon},14z');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final clinics = _services
        .map((s) => Clinic(
              name: (s['name'] ?? 'Clinic') as String,
              address: (s['location'] ?? '') as String,
              lat: (s['latitude'] as num?)?.toDouble(),
              lon: (s['longitude'] as num?)?.toDouble(),
            ))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('nearby_clinics')),
        actions: [
          IconButton(
            tooltip: 'Open in Google Maps',
            onPressed: _openNearbyClinics,
            icon: const Icon(Icons.map_outlined),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.map_outlined, color: Color(0xFF1E88E5)),
                          title: const Text('View Nearby Facilities on Map'),
                          subtitle: Text(loc.t('map_hint')),
                          trailing: ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/map'),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Open Map'),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _openNearbyClinics,
                            icon: const Icon(Icons.near_me_outlined),
                            label: Text(loc.t('open_nearby_clinics')),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            loc.t('map_hint'),
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: clinics.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final c = clinics[index];
                          // Access the original service map to read fields not present in Clinic (e.g., contact)
                          final data = _services[index];
                          final dist = _distanceKmOf(c);
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: ListTile(
                                leading: const Icon(Icons.local_hospital, color: Color(0xFF1E88E5)),
                                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.address.isEmpty ? 'Unknown address' : c.address),
                                    const SizedBox(height: 4),
                                    if ((data['contact'] as String?)?.isNotEmpty == true)
                                      Text(
                                        'Phone: ${(data['contact'] as String)}',
                                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                                      ),
                                    const SizedBox(height: 4),
                                    if (dist != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE3F2FD),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text('${dist.toStringAsFixed(1)} km away', style: const TextStyle(fontSize: 12, color: Color(0xFF1E88E5))),
                                      ),
                                  ],
                                ),
                                trailing: Wrap(
                                  spacing: 4,
                                  children: [
                                    IconButton(
                                      tooltip: 'Open on map',
                                      icon: const Icon(Icons.map_outlined, color: Color(0xFF43A047)),
                                      onPressed: () => Navigator.pushNamed(context, '/map'),
                                    ),
                                    if ((data['contact'] as String?)?.isNotEmpty == true)
                                      IconButton(
                                        tooltip: 'Call',
                                        icon: const Icon(Icons.call, color: Color(0xFF43A047)),
                                        onPressed: () async {
                                          final tel = Uri.parse('tel:${(data['contact'] as String)}');
                                          await launchUrl(tel, mode: LaunchMode.externalApplication);
                                        },
                                      ),
                                    IconButton(
                                      tooltip: 'Directions',
                                      icon: const Icon(Icons.directions, color: Color(0xFF1E88E5)),
                                      onPressed: () => _openDirectionsTo(c),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class Clinic {
  final String name;
  final String address;
  final double? lat;
  final double? lon;
  const Clinic({required this.name, required this.address, this.lat, this.lon});
}
