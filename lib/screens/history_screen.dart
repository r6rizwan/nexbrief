import 'package:flutter/material.dart';

import '../models/meeting_history_entry.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.isBusy,
    required this.history,
    required this.formatTimestamp,
    required this.onLoad,
    required this.onDelete,
  });

  final bool isBusy;
  final List<MeetingHistoryEntry> history;
  final String Function(String) formatTimestamp;
  final void Function(MeetingHistoryEntry) onLoad;
  final Future<void> Function(MeetingHistoryEntry) onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text(
            'Meeting History',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (history.isEmpty)
            const Text('No saved meetings yet.')
          else
            ...history.map((entry) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatTimestamp(entry.createdAtIso),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.transcript.isEmpty
                            ? '(No transcript)'
                            : entry.transcript
                                  .replaceAll('\n', ' ')
                                  .substring(
                                    0,
                                    entry.transcript.length > 120
                                        ? 120
                                        : entry.transcript.length,
                                  ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: isBusy ? null : () => onLoad(entry),
                            icon: const Icon(Icons.history_toggle_off),
                            label: const Text('Load'),
                          ),
                          OutlinedButton.icon(
                            onPressed: isBusy
                                ? null
                                : () async {
                                    final shouldDelete =
                                        await showDialog<bool>(
                                          context: context,
                                          builder: (dialogContext) {
                                            return AlertDialog(
                                              title: const Text(
                                                'Delete Meeting',
                                              ),
                                              content: const Text(
                                                'This removes the history item and its markdown file. Continue?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    dialogContext,
                                                  ).pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () => Navigator.of(
                                                    dialogContext,
                                                  ).pop(true),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            );
                                          },
                                        ) ??
                                        false;
                                    if (!shouldDelete) return;
                                    await onDelete(entry);
                                  },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
