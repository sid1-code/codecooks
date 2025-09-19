import 'package:flutter/material.dart';
import '../services/consent_service.dart';
import '../services/storage_service.dart';
import '../i18n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _consent = ConsentService();
  final _storage = StorageService();

  bool _loading = true;
  bool _store = true;
  bool _mic = true;
  bool _location = true;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = await _consent.isStoreAllowed();
    final mic = await _consent.isMicAllowed();
    final loc = await _consent.isLocationAllowed();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _store = store;
      _mic = mic;
      _location = loc;
    });
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    await _consent.setStoreAllowed(_store);
    await _consent.setMicAllowed(_mic);
    await _consent.setLocationAllowed(_location);
    if (!_store) {
      // If disabling storage, clear immediately
      setState(() => _clearing = true);
      try {
        await _storage.clearAllData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All local data cleared')),
          );
        }
      } finally {
        if (mounted) setState(() => _clearing = false);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _clearAll() async {
    setState(() => _clearing = true);
    try {
      await _storage.clearAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All local data cleared')),
        );
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Language', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _langChip(context, 'English', const Locale('en')),
                    _langChip(context, 'हिन्दी', const Locale('hi')),
                    _langChip(context, 'Español', const Locale('es')),
                    _langChip(context, 'Français', const Locale('fr')),
                  ],
                ),
                const Divider(),
                SwitchListTile.adaptive(
                  value: _store,
                  onChanged: (v) => setState(() => _store = v),
                  title: const Text('Allow local storage (encrypted)', style: TextStyle(fontSize: 16)),
                  subtitle: const Text('Store chat history securely on this device'),
                ),
                const Divider(),
                SwitchListTile.adaptive(
                  value: _mic,
                  onChanged: (v) => setState(() => _mic = v),
                  title: const Text('Allow microphone', style: TextStyle(fontSize: 16)),
                  subtitle: const Text('Use voice input for messages'),
                ),
                SwitchListTile.adaptive(
                  value: _location,
                  onChanged: (v) => setState(() => _location = v),
                  title: const Text('Allow location', style: TextStyle(fontSize: 16)),
                  subtitle: const Text('Find nearby facilities and directions'),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _clearing ? null : _clearAll,
                  icon: const Icon(Icons.delete_forever),
                  label: _clearing
                      ? const Text('Clearing...')
                      : const Text('Clear all data'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: _loading ? const Text('Saving...') : const Text('Save settings'),
                ),
              ],
            ),
    );
  }

  Widget _langChip(BuildContext context, String label, Locale locale) {
    final current = LanguageScope.of(context);
    final isSelected = current.languageCode == locale.languageCode;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => LanguageScope.setLocale(context, locale),
    );
  }
}
