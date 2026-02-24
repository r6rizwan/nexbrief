import 'package:flutter/material.dart';

import '../models/action_item.dart';

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({
    super.key,
    required this.status,
    required this.isBusy,
    required this.transcriptController,
    required this.summaryKeyPointsController,
    required this.summaryDecisionsController,
    required this.summaryRisksController,
    required this.summaryNextStepsController,
    required this.markdownController,
    required this.lastExportPath,
    required this.items,
    required this.categoryColor,
    required this.onGenerateSummary,
    required this.onExtractActions,
    required this.onAddItem,
    required this.onEditItem,
    required this.onDeleteItem,
    required this.onExportMarkdown,
    required this.onDeleteMarkdown,
  });

  final String status;
  final bool isBusy;
  final TextEditingController transcriptController;
  final TextEditingController summaryKeyPointsController;
  final TextEditingController summaryDecisionsController;
  final TextEditingController summaryRisksController;
  final TextEditingController summaryNextStepsController;
  final TextEditingController markdownController;
  final String lastExportPath;
  final List<ActionItem> items;
  final Color Function(String) categoryColor;
  final VoidCallback onGenerateSummary;
  final VoidCallback onExtractActions;
  final VoidCallback onAddItem;
  final void Function(ActionItem item, int index) onEditItem;
  final void Function(int index) onDeleteItem;
  final VoidCallback onExportMarkdown;
  final VoidCallback onDeleteMarkdown;

  Widget _card({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8CEBC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0B5D4B)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(subtitle, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

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
            _card(
              icon: Icons.subject_outlined,
              title: 'Transcript',
              subtitle: 'Paste or edit meeting text',
              children: [
                TextField(
                  controller: transcriptController,
                  minLines: 7,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    hintText: 'Paste meeting transcript here',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Status: $status',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            _card(
              icon: Icons.summarize_outlined,
              title: 'Structured Summary',
              subtitle: 'Generate key points, decisions, risks and next steps',
              children: [
                FilledButton.icon(
                  onPressed: isBusy ? null : onGenerateSummary,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate Summary'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: summaryKeyPointsController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Key Points'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: summaryDecisionsController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Decisions'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: summaryRisksController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Risks'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: summaryNextStepsController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Next Steps'),
                ),
              ],
            ),
            _card(
              icon: Icons.auto_awesome_outlined,
              title: 'Action Extraction',
              subtitle: 'Fully local rule-based extraction',
              children: [
                FilledButton.icon(
                  onPressed: isBusy ? null : onExtractActions,
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: const Text('Run Rule Extraction'),
                ),
              ],
            ),
            _card(
              icon: Icons.checklist_rtl_outlined,
              title: 'Action Items',
              subtitle: 'Owners, due dates and categories (editable)',
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onAddItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                  ),
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const Text('No action items yet. Run extraction first.')
                else
                  ...items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final accent = categoryColor(item.category);
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 380;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD8CEBC)),
                          ),
                          child: compact
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 54,
                                          decoration: BoxDecoration(
                                            color: accent,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                'Owner: ${item.owner} | Due: ${item.due}',
                                              ),
                                              Text(
                                                item.category,
                                                style: TextStyle(color: accent),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: isBusy
                                              ? null
                                              : () => onEditItem(item, index),
                                          icon: const Icon(Icons.edit_outlined),
                                          label: const Text('Edit'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: isBusy
                                              ? null
                                              : () => onDeleteItem(index),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          label: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        color: accent,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            'Owner: ${item.owner} | Due: ${item.due}',
                                          ),
                                          Text(
                                            item.category,
                                            style: TextStyle(color: accent),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        IconButton(
                                          onPressed: isBusy
                                              ? null
                                              : () => onEditItem(item, index),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                        IconButton(
                                          onPressed: isBusy
                                              ? null
                                              : () => onDeleteItem(index),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                        );
                      },
                    );
                  }),
              ],
            ),
            _card(
              icon: Icons.file_download_outlined,
              title: 'Markdown Export',
              subtitle: 'Generate and store meeting summary locally',
              children: [
                FilledButton.icon(
                  onPressed: isBusy ? null : onExportMarkdown,
                  icon: const Icon(Icons.download_for_offline_outlined),
                  label: const Text('Generate + Export Markdown'),
                ),
                if (lastExportPath.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Saved at: $lastExportPath'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: isBusy ? null : onDeleteMarkdown,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete Markdown File'),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: markdownController,
                  minLines: 6,
                  maxLines: 14,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Markdown Preview',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
