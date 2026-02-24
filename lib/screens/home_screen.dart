import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.status,
    required this.itemsCount,
    required this.historyCount,
    required this.onOpenWorkspace,
    required this.onOpenHistory,
    required this.onGenerateSummary,
    required this.onExtractActions,
  });

  final String status;
  final int itemsCount;
  final int historyCount;
  final VoidCallback onOpenWorkspace;
  final VoidCallback onOpenHistory;
  final VoidCallback? onGenerateSummary;
  final VoidCallback? onExtractActions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3D9), Color(0xFFF3EFE6), Color(0xFFE6F1EC)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF103C35), Color(0xFF1D6D5C)],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NexBrief',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Meeting summarizer and action tracker.',
                    style: TextStyle(color: Color(0xFFE3FFF6), fontSize: 13),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text('$itemsCount Action Items'),
                  avatar: const Icon(Icons.task_alt, size: 16),
                ),
                Chip(
                  label: Text('$historyCount Saved Meetings'),
                  avatar: const Icon(Icons.history, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Status: $status',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onOpenWorkspace,
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('Go To Workspace'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onGenerateSummary,
              icon: const Icon(Icons.summarize_outlined),
              label: const Text('Generate Summary'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onExtractActions,
              icon: const Icon(Icons.play_arrow_outlined),
              label: const Text('Run Rule Extraction'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onOpenHistory,
              icon: const Icon(Icons.history_outlined),
              label: const Text('Open History'),
            ),
          ],
        ),
      ),
    );
  }
}
