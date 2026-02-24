import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/action_item.dart';
import '../models/meeting_history_entry.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'workspace_screen.dart';

class NexBriefShell extends StatefulWidget {
  const NexBriefShell({super.key});

  @override
  State<NexBriefShell> createState() => _NexBriefShellState();
}

class _NexBriefShellState extends State<NexBriefShell> {
  final _transcriptController = TextEditingController();
  final _markdownController = TextEditingController();
  final _summaryKeyPointsController = TextEditingController();
  final _summaryDecisionsController = TextEditingController();
  final _summaryRisksController = TextEditingController();
  final _summaryNextStepsController = TextEditingController();

  int _tabIndex = 0;
  bool _isBusy = false;
  String _status = 'Idle';
  String _lastExportPath = '';

  List<ActionItem> _items = [];
  List<MeetingHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    _markdownController.dispose();
    _summaryKeyPointsController.dispose();
    _summaryDecisionsController.dispose();
    _summaryRisksController.dispose();
    _summaryNextStepsController.dispose();
    super.dispose();
  }

  Future<File> _historyFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/meeting_history.json');
  }

  Future<void> _loadHistory() async {
    try {
      final file = await _historyFile();
      if (!file.existsSync()) return;

      final content = await file.readAsString();
      if (content.trim().isEmpty) return;

      final decoded = jsonDecode(content);
      if (decoded is! List) return;

      final entries = <MeetingHistoryEntry>[];
      for (final row in decoded) {
        if (row is Map<String, dynamic>) {
          entries.add(MeetingHistoryEntry.fromMap(row));
        }
      }

      entries.sort((a, b) => b.createdAtIso.compareTo(a.createdAtIso));
      if (!mounted) return;
      setState(() {
        _history = entries;
      });
    } catch (_) {}
  }

  Future<void> _persistHistory() async {
    final file = await _historyFile();
    final encoded = jsonEncode(_history.map((entry) => entry.toMap()).toList());
    await file.writeAsString(encoded);
  }

  void _setStatus(String status) {
    if (!mounted) return;
    setState(() {
      _status = status;
    });
  }

  Future<void> _runBusy(String status, Future<void> Function() work) async {
    setState(() {
      _isBusy = true;
      _status = status;
    });
    try {
      await work();
    } catch (e) {
      _setStatus(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _switchTab(int index) {
    setState(() {
      _tabIndex = index;
    });
  }

  void _generateStructuredSummaryRuleBased() {
    final transcript = _transcriptController.text.trim();
    if (transcript.isEmpty) {
      _setStatus('Transcript is empty');
      return;
    }

    final sentences = _candidateActionLines(transcript);
    final keyPoints = <String>[];
    final decisions = <String>[];
    final risks = <String>[];
    final nextSteps = <String>[];

    final decisionMatcher = RegExp(
      r'\b(decided|decision|agreed|approved|resolved|finalized)\b',
      caseSensitive: false,
    );
    final riskMatcher = RegExp(
      r'\b(risk|blocker|issue|concern|delay|dependency|problem)\b',
      caseSensitive: false,
    );
    final nextStepMatcher = RegExp(
      r'\b(next step|action|todo|to-do|will|needs?\s+to|should|must|plan to|follow up|deliver|complete|submit|send|prepare|review|schedule)\b',
      caseSensitive: false,
    );

    for (final sentence in sentences) {
      if (keyPoints.length < 6) keyPoints.add(sentence);
      if (decisionMatcher.hasMatch(sentence) && decisions.length < 6) {
        decisions.add(sentence);
      }
      if (riskMatcher.hasMatch(sentence) && risks.length < 6) {
        risks.add(sentence);
      }
      if (nextStepMatcher.hasMatch(sentence) && nextSteps.length < 8) {
        nextSteps.add(_normalizeActionTitle(sentence));
      }
    }

    if (decisions.isEmpty) decisions.add('No explicit decisions detected.');
    if (risks.isEmpty) risks.add('No explicit risks detected.');
    if (nextSteps.isEmpty) nextSteps.add('No explicit next steps detected.');

    _summaryKeyPointsController.text = _toBulletText(keyPoints);
    _summaryDecisionsController.text = _toBulletText(decisions);
    _summaryRisksController.text = _toBulletText(risks);
    _summaryNextStepsController.text = _toBulletText(nextSteps);
    _setStatus('Summary generated from local rules');
  }

  void _extractActionsRuleBased() {
    final transcript = _transcriptController.text.trim();
    if (transcript.isEmpty) {
      _setStatus('Transcript is empty');
      return;
    }

    final sentences = _candidateActionLines(transcript);
    final verbs = RegExp(
      r'\b(action|todo|to-do|follow up|follow-up|will|needs?\s+to|should|must|plan to|please|send|prepare|share|review|call|email|schedule|finalize|update|submit|deliver|complete|close|assign|create)\b',
      caseSensitive: false,
    );

    final items = <ActionItem>[];
    for (final sentence in sentences) {
      if (!verbs.hasMatch(sentence)) continue;
      final title = _normalizeActionTitle(sentence);
      if (title.isEmpty) continue;

      items.add(
        ActionItem(
          title: title.length > 140 ? '${title.substring(0, 140)}...' : title,
          owner: _extractOwner(sentence),
          due: _extractDue(sentence),
          category: _detectCategory(sentence),
        ),
      );
    }

    final uniqueItems = <ActionItem>[];
    final seenTitles = <String>{};
    for (final item in items) {
      if (seenTitles.add(item.title.toLowerCase())) {
        uniqueItems.add(item);
      }
    }

    setState(() {
      _items = uniqueItems;
    });
    _setStatus('Rule extraction found ${uniqueItems.length} action items');
  }

  Future<void> _openActionItemEditor({
    ActionItem? initialItem,
    int? index,
  }) async {
    final titleController = TextEditingController(
      text: initialItem?.title ?? '',
    );
    final ownerController = TextEditingController(
      text: initialItem?.owner ?? 'Unassigned',
    );
    final dueController = TextEditingController(
      text: initialItem?.due ?? 'Not specified',
    );
    final categoryController = TextEditingController(
      text: initialItem?.category ?? 'General',
    );

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(index == null ? 'Add Action Item' : 'Edit Action Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ownerController,
                  decoration: const InputDecoration(labelText: 'Owner'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: dueController,
                  decoration: const InputDecoration(labelText: 'Due'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      titleController.dispose();
      ownerController.dispose();
      dueController.dispose();
      categoryController.dispose();
      return;
    }

    final nextItem = ActionItem(
      title: titleController.text.trim().isEmpty
          ? 'Untitled task'
          : titleController.text.trim(),
      owner: ownerController.text.trim().isEmpty
          ? 'Unassigned'
          : ownerController.text.trim(),
      due: dueController.text.trim().isEmpty
          ? 'Not specified'
          : dueController.text.trim(),
      category: categoryController.text.trim().isEmpty
          ? 'General'
          : categoryController.text.trim(),
    );

    setState(() {
      if (index == null) {
        _items = [..._items, nextItem];
      } else {
        final updated = [..._items];
        updated[index] = nextItem;
        _items = updated;
      }
    });

    titleController.dispose();
    ownerController.dispose();
    dueController.dispose();
    categoryController.dispose();
  }

  void _removeActionItem(int index) {
    setState(() {
      _items = [..._items]..removeAt(index);
    });
  }

  Future<void> _saveCurrentMeetingToHistory({
    required String markdownPath,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    final entry = MeetingHistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAtIso: nowIso,
      transcript: _transcriptController.text.trim(),
      summaryKeyPoints: _summaryKeyPointsController.text.trim(),
      summaryDecisions: _summaryDecisionsController.text.trim(),
      summaryRisks: _summaryRisksController.text.trim(),
      summaryNextSteps: _summaryNextStepsController.text.trim(),
      actionItems: _items,
      markdownPath: markdownPath,
    );

    setState(() {
      _history = [entry, ..._history];
    });
    await _persistHistory();
  }

  void _loadHistoryEntry(MeetingHistoryEntry entry) {
    setState(() {
      _transcriptController.text = entry.transcript;
      _summaryKeyPointsController.text = entry.summaryKeyPoints;
      _summaryDecisionsController.text = entry.summaryDecisions;
      _summaryRisksController.text = entry.summaryRisks;
      _summaryNextStepsController.text = entry.summaryNextSteps;
      _items = entry.actionItems.map((item) => item.copyWith()).toList();
      _markdownController.text = _buildMarkdown();
      _lastExportPath = entry.markdownPath;
      _tabIndex = 1;
    });
    _setStatus('Loaded meeting from history');
  }

  Future<void> _deleteHistoryEntry(MeetingHistoryEntry entry) async {
    await _runBusy('Deleting history entry...', () async {
      final deletedMarkdown = await _deleteFileIfExists(entry.markdownPath);
      final removedLastExport = _lastExportPath == entry.markdownPath;

      setState(() {
        _history = _history.where((e) => e.id != entry.id).toList();
        if (removedLastExport) {
          _lastExportPath = '';
        }
      });

      await _persistHistory();
      _setStatus(
        deletedMarkdown
            ? 'History entry and markdown file deleted'
            : 'History entry deleted',
      );
    });
  }

  Future<void> _generateAndExportMarkdown() async {
    final markdown = _buildMarkdown();
    _markdownController.text = markdown;

    await _runBusy('Exporting markdown...', () async {
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'meeting_summary_${DateTime.now().millisecondsSinceEpoch}.md';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(markdown);

      setState(() {
        _lastExportPath = file.path;
      });
      await _saveCurrentMeetingToHistory(markdownPath: file.path);
      _setStatus('Markdown exported to ${file.path}');
    });
  }

  Future<void> _deleteLastMarkdownFile() async {
    final path = _lastExportPath.trim();
    if (path.isEmpty) {
      _setStatus('No exported markdown to delete');
      return;
    }

    await _runBusy('Deleting markdown file...', () async {
      final deleted = await _deleteFileIfExists(path);
      setState(() {
        _lastExportPath = '';
      });
      _setStatus(deleted ? 'Markdown file deleted' : 'Markdown file not found');
    });
  }

  Future<bool> _deleteFileIfExists(String path) async {
    try {
      if (path.trim().isEmpty) return false;
      final file = File(path);
      if (!await file.exists()) return false;
      await file.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  String _buildMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# Meeting Summary');
    buffer.writeln();
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln();
    buffer.writeln('## Transcript');
    buffer.writeln();
    buffer.writeln(
      _transcriptController.text.trim().isEmpty
          ? '(No transcript)'
          : _transcriptController.text.trim(),
    );
    buffer.writeln();
    buffer.writeln('## Structured Summary');
    buffer.writeln();
    _writeSummarySection(
      buffer,
      'Key Points',
      _summaryKeyPointsController.text.trim(),
    );
    _writeSummarySection(
      buffer,
      'Decisions',
      _summaryDecisionsController.text.trim(),
    );
    _writeSummarySection(buffer, 'Risks', _summaryRisksController.text.trim());
    _writeSummarySection(
      buffer,
      'Next Steps',
      _summaryNextStepsController.text.trim(),
    );
    buffer.writeln();
    buffer.writeln('## Action Items');
    buffer.writeln();

    if (_items.isEmpty) {
      buffer.writeln('No action items found.');
    } else {
      for (var i = 0; i < _items.length; i++) {
        final item = _items[i];
        buffer.writeln('${i + 1}. **${item.title}**  ');
        buffer.writeln('   - Owner: ${item.owner}  ');
        buffer.writeln('   - Due: ${item.due}  ');
        buffer.writeln('   - Category: ${item.category}');
      }
    }

    return buffer.toString();
  }

  void _writeSummarySection(StringBuffer buffer, String title, String content) {
    buffer.writeln('### $title');
    if (content.isEmpty) {
      buffer.writeln('- Not provided');
      buffer.writeln();
      return;
    }

    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      buffer.writeln('- Not provided');
      buffer.writeln();
      return;
    }

    for (final line in lines) {
      final normalized = line.startsWith('- ') ? line : '- $line';
      buffer.writeln(normalized);
    }
    buffer.writeln();
  }

  String _toBulletText(List<String> values) {
    if (values.isEmpty) return '';
    return values.map((value) => '- $value').join('\n');
  }

  String _formatHistoryTimestamp(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  String _extractOwner(String sentence) {
    final patterns = [
      RegExp(
        r'\bowner\s*[:\-]\s*([A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)?)\b',
        caseSensitive: false,
      ),
      RegExp(r'\b([A-Z][a-zA-Z]+)\s+(?:will|should|needs?\s+to)\b'),
      RegExp(r'\b([A-Z][a-zA-Z]+)\s+to\b'),
      RegExp(
        r'\bassign(?:ed)?\s+to\s+([A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)?)\b',
        caseSensitive: false,
      ),
      RegExp(r'@([a-zA-Z0-9_]+)'),
      RegExp(r'\b([a-zA-Z0-9._%+-]+)@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b'),
    ];

    for (final pattern in patterns) {
      final m = pattern.firstMatch(sentence);
      if (m != null) return m.group(1) ?? 'Unassigned';
    }
    return 'Unassigned';
  }

  String _extractDue(String sentence) {
    final patterns = [
      RegExp(
        r'\b(today|tomorrow|eod|eow|end of day|end of week|next\s+week|this\s+week|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(jan|january|feb|february|mar|march|apr|april|may|jun|june|jul|july|aug|august|sep|sept|september|oct|october|nov|november|dec|december)\s+\d{1,2}(?:,\s*\d{2,4})?\b',
        caseSensitive: false,
      ),
      RegExp(r'\b\d{1,2}[/-]\d{1,2}([/-]\d{2,4})?\b'),
      RegExp(r'\b\d{4}-\d{1,2}-\d{1,2}\b'),
      RegExp(r'\b\d{1,2}:\d{2}\s?(am|pm)?\b', caseSensitive: false),
      RegExp(r'\b\d{1,2}\s?(am|pm)\b', caseSensitive: false),
      RegExp(r'\bby\s+[^,.!?]+', caseSensitive: false),
      RegExp(r'\bbefore\s+[^,.!?]+', caseSensitive: false),
      RegExp(r'\bon\s+[^,.!?]+', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final m = pattern.firstMatch(sentence);
      if (m != null) return m.group(0) ?? 'Not specified';
    }
    return 'Not specified';
  }

  String _detectCategory(String sentence) {
    final s = sentence.toLowerCase();
    if (RegExp(r'invoice|budget|payment|tax|audit|account').hasMatch(s)) {
      return 'Finance';
    }
    if (RegExp(r'client|proposal|lead|contract|pipeline').hasMatch(s)) {
      return 'Sales';
    }
    if (RegExp(r'marketing|campaign|brand|content|seo|social').hasMatch(s)) {
      return 'Marketing';
    }
    if (RegExp(r'deploy|bug|release|api|backend|frontend').hasMatch(s)) {
      return 'Engineering';
    }
    if (RegExp(r'vendor|logistics|procurement|approval|process').hasMatch(s)) {
      return 'Operations';
    }
    if (RegExp(r'interview|hiring|onboard|policy|candidate').hasMatch(s)) {
      return 'HR';
    }
    return 'General';
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'finance':
        return const Color(0xFF9C4221);
      case 'sales':
        return const Color(0xFF2B6CB0);
      case 'marketing':
        return const Color(0xFFB7791F);
      case 'engineering':
        return const Color(0xFF2F855A);
      case 'operations':
        return const Color(0xFF805AD5);
      case 'hr':
        return const Color(0xFFC05621);
      default:
        return const Color(0xFF4A5568);
    }
  }

  List<String> _candidateActionLines(String transcript) {
    final normalized = transcript.replaceAll('\r\n', '\n');
    final candidates = <String>[];

    for (final rawLine in normalized.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final withoutListPrefix = line
          .replaceFirst(RegExp(r'^[-*•]\s*'), '')
          .replaceFirst(RegExp(r'^\d+[\).\s]+'), '')
          .trim();
      if (withoutListPrefix.isEmpty) continue;

      final sentenceParts = withoutListPrefix.split(RegExp(r'(?<=[.!?;])\s+'));
      for (final part in sentenceParts) {
        final trimmed = part.trim();
        if (trimmed.isNotEmpty) {
          candidates.add(trimmed);
        }
      }
    }

    if (candidates.isEmpty) {
      return normalized
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return candidates;
  }

  String _normalizeActionTitle(String sentence) {
    var normalized = sentence.trim();
    normalized = normalized.replaceFirst(RegExp(r'^[-*•]\s*'), '');
    normalized = normalized.replaceFirst(RegExp(r'^\d+[\).\s]+'), '');
    normalized = normalized.replaceFirst(
      RegExp(r'^(action item|todo|to-do)\s*[:\-]\s*', caseSensitive: false),
      '',
    );
    normalized = normalized.replaceFirst(
      RegExp(r'^[A-Za-z][A-Za-z0-9_ ]{0,20}\s*:\s*'),
      '',
    );
    return normalized.trim();
  }

  @override
  Widget build(BuildContext context) {
    const tabTitles = ['Home', 'Workspace', 'History', 'Settings'];
    final screens = [
      HomeScreen(
        status: _status,
        itemsCount: _items.length,
        historyCount: _history.length,
        onOpenWorkspace: () => _switchTab(1),
        onOpenHistory: () => _switchTab(2),
        onGenerateSummary: _isBusy ? null : _generateStructuredSummaryRuleBased,
        onExtractActions: _isBusy ? null : _extractActionsRuleBased,
      ),
      WorkspaceScreen(
        status: _status,
        isBusy: _isBusy,
        transcriptController: _transcriptController,
        summaryKeyPointsController: _summaryKeyPointsController,
        summaryDecisionsController: _summaryDecisionsController,
        summaryRisksController: _summaryRisksController,
        summaryNextStepsController: _summaryNextStepsController,
        markdownController: _markdownController,
        lastExportPath: _lastExportPath,
        items: _items,
        categoryColor: _categoryColor,
        onGenerateSummary: _generateStructuredSummaryRuleBased,
        onExtractActions: _extractActionsRuleBased,
        onAddItem: () => _openActionItemEditor(),
        onEditItem: (item, index) =>
            _openActionItemEditor(initialItem: item, index: index),
        onDeleteItem: _removeActionItem,
        onExportMarkdown: _generateAndExportMarkdown,
        onDeleteMarkdown: _deleteLastMarkdownFile,
      ),
      HistoryScreen(
        isBusy: _isBusy,
        history: _history,
        formatTimestamp: _formatHistoryTimestamp,
        onLoad: _loadHistoryEntry,
        onDelete: _deleteHistoryEntry,
      ),
      SettingsScreen(
        status: _status,
        onClearWorkspace: () {
          setState(() {
            _transcriptController.clear();
            _summaryKeyPointsController.clear();
            _summaryDecisionsController.clear();
            _summaryRisksController.clear();
            _summaryNextStepsController.clear();
            _markdownController.clear();
            _items = [];
            _lastExportPath = '';
          });
          _setStatus('Workspace cleared');
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(tabTitles[_tabIndex])),
      body: IndexedStack(index: _tabIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: _switchTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Workspace',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
