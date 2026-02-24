import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.status,
    required this.onClearWorkspace,
  });

  final String status;
  final VoidCallback onClearWorkspace;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NexBrief runs fully on-device.'),
                  SizedBox(height: 6),
                  Text('No API key, backend, or paid services are required.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Status: $status'),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onClearWorkspace,
            icon: const Icon(Icons.clear_all_outlined),
            label: const Text('Clear Workspace'),
          ),
        ],
      ),
    );
  }
}
