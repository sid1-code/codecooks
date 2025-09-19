import 'package:flutter/material.dart';
import '../services/consent_service.dart';

class ConsentDialog extends StatefulWidget {
  const ConsentDialog({super.key});

  @override
  State<ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<ConsentDialog> {
  bool store = true;
  bool mic = true;
  bool location = true;
  bool saving = false;

  Future<void> _save() async {
    setState(() => saving = true);
    final svc = ConsentService();
    await svc.setStoreAllowed(store);
    await svc.setMicAllowed(mic);
    await svc.setLocationAllowed(location);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Privacy & Permissions'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Please review and consent to these options:'),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: store,
            onChanged: (v) => setState(() => store = v ?? false),
            title: const Text('Allow local storage (encrypted)'),
            subtitle: const Text('Store chat history securely on this device'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            value: mic,
            onChanged: (v) => setState(() => mic = v ?? false),
            title: const Text('Allow microphone'),
            subtitle: const Text('Use voice input for messages'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            value: location,
            onChanged: (v) => setState(() => location = v ?? false),
            title: const Text('Allow location'),
            subtitle: const Text('Find nearby facilities and directions'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: saving ? null : _save,
          child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
        ),
      ],
    );
  }
}
