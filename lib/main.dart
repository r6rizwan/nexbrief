import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

void main() {
  runApp(const MeetingSummarizerApp());
}

class MeetingSummarizerApp extends StatelessWidget {
  const MeetingSummarizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meeting Summarizer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B5D4B),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3EFE6),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFCF5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD4CAB7)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD4CAB7)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF0B5D4B), width: 1.4),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        useMaterial3: true,
      ),
      home: const MeetingHomePage(),
    );
  }
}

class ActionItem {
  ActionItem({
    required this.title,
    required this.owner,
    required this.due,
    required this.category,
  });

  final String title;
  final String owner;
  final String due;
  final String category;

  factory ActionItem.fromMap(Map<String, dynamic> map) {
    return ActionItem(
      title: _normalizeString(map['title'], fallback: 'Untitled task'),
      owner: _normalizeString(map['owner'], fallback: 'Unassigned'),
      due: _normalizeString(map['due'], fallback: 'Not specified'),
      category: _normalizeString(map['category'], fallback: 'General'),
    );
  }
}

class MeetingHomePage extends StatefulWidget {
  const MeetingHomePage({super.key});

  @override
  State<MeetingHomePage> createState() => _MeetingHomePageState();
}

class _MeetingHomePageState extends State<MeetingHomePage> {
  final _apiKeyController = TextEditingController();
  final _transcriptController = TextEditingController();
  final _markdownController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();

  String? _audioPath;
  bool _isRecording = false;
  bool _isBusy = false;
  String _status = 'Idle';
  String _lastExportPath = '';
  String _extractMode = 'ai';

  List<ActionItem> _items = [];

  @override
  void dispose() {
    _apiKeyController.dispose();
    _transcriptController.dispose();
    _markdownController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      _setStatus('Microphone permission denied');
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/meeting_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(const RecordConfig(), path: path);
    setState(() {
      _audioPath = path;
      _isRecording = true;
      _status = 'Recording...';
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _status = 'Recording stopped';
    });
  }

  Future<void> _transcribeAudio() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      _setStatus('Enter OpenAI API key first');
      return;
    }
    if (_audioPath == null || !File(_audioPath!).existsSync()) {
      _setStatus('No recording found. Record audio first.');
      return;
    }

    await _runBusy('Transcribing audio...', () async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
      );
      request.headers['Authorization'] = 'Bearer $key';
      request.fields['model'] = 'gpt-4o-transcribe';
      request.files.add(await http.MultipartFile.fromPath('file', _audioPath!));

      final streamed = await request.send();
      final responseBody = await streamed.stream.bytesToString();
      if (streamed.statusCode < 200 || streamed.statusCode > 299) {
        throw Exception('Transcription failed (${streamed.statusCode}): $responseBody');
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final text = _normalizeString(json['text'], fallback: '');
      if (text.isEmpty) {
        throw Exception('Transcription returned empty text');
      }

      _transcriptController.text = text;
      _setStatus('Transcription completed');
    });
  }

  Future<void> _extractActionsWithAi() async {
    final key = _apiKeyController.text.trim();
    final transcript = _transcriptController.text.trim();

    if (key.isEmpty) {
      _setStatus('Enter OpenAI API key first');
      return;
    }
    if (transcript.isEmpty) {
      _setStatus('Transcript is empty');
      return;
    }

    await _runBusy('Extracting action items...', () async {
      final prompt = '''
Extract action items from this meeting transcript.
Return only valid JSON array.
Each array item must contain: title, owner, due, category.
If owner is missing use "Unassigned".
If due is missing use "Not specified".
Transcript:
$transcript
''';

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/responses'),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.authorizationHeader: 'Bearer $key',
        },
        body: jsonEncode({
          'model': 'gpt-4.1-mini',
          'input': prompt,
          'temperature': 0.1,
        }),
      );

      if (response.statusCode < 200 || response.statusCode > 299) {
        throw Exception('Extraction failed (${response.statusCode}): ${response.body}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final outputText = _extractOutputText(json).trim();
      if (outputText.isEmpty) {
        throw Exception('Model returned empty output');
      }

      final cleaned = outputText
          .replaceFirst(RegExp(r'^```json\s*', caseSensitive: false), '')
          .replaceFirst(RegExp(r'^```\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '');

      final decoded = jsonDecode(cleaned);
      if (decoded is! List) {
        throw Exception('Expected JSON array from model');
      }

      final parsed = <ActionItem>[];
      for (final row in decoded) {
        if (row is Map<String, dynamic>) {
          parsed.add(ActionItem.fromMap(row));
        }
      }

      setState(() {
        _items = parsed;
      });
      _setStatus('Extracted ${parsed.length} action items');
    });
  }

  void _extractActionsRuleBased() {
    final transcript = _transcriptController.text.trim();
    if (transcript.isEmpty) {
      _setStatus('Transcript is empty');
      return;
    }

    final sentences = transcript
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final verbs = RegExp(
      r'\b(will|need to|should|must|follow up|send|prepare|share|review|call|email|schedule|finalize|update|submit)\b',
      caseSensitive: false,
    );

    final items = <ActionItem>[];
    for (final sentence in sentences) {
      if (!verbs.hasMatch(sentence)) continue;

      items.add(
        ActionItem(
          title: sentence.length > 140 ? '${sentence.substring(0, 140)}...' : sentence,
          owner: _extractOwner(sentence),
          due: _extractDue(sentence),
          category: _detectCategory(sentence),
        ),
      );
    }

    setState(() {
      _items = items;
    });
    _setStatus('Rule extraction found ${items.length} action items');
  }

  Future<void> _generateAndExportMarkdown() async {
    final markdown = _buildMarkdown();
    _markdownController.text = markdown;

    await _runBusy('Exporting markdown...', () async {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'meeting_summary_${DateTime.now().millisecondsSinceEpoch}.md';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(markdown);

      setState(() {
        _lastExportPath = file.path;
      });
      _setStatus('Markdown exported to ${file.path}');
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

  void _setStatus(String status) {
    if (!mounted) return;
    setState(() {
      _status = status;
    });
  }

  String _buildMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# Meeting Summary');
    buffer.writeln();
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln();
    buffer.writeln('## Transcript');
    buffer.writeln();
    buffer.writeln(_transcriptController.text.trim().isEmpty ? '(No transcript)' : _transcriptController.text.trim());
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

  String _extractOwner(String sentence) {
    final patterns = [
      RegExp(r'\b([A-Z][a-z]+)\s+will\b'),
      RegExp(r'\bassign(?:ed)?\s+to\s+([A-Z][a-z]+)\b', caseSensitive: false),
      RegExp(r'@([a-zA-Z0-9_]+)'),
    ];

    for (final pattern in patterns) {
      final m = pattern.firstMatch(sentence);
      if (m != null) return m.group(1) ?? 'Unassigned';
    }
    return 'Unassigned';
  }

  String _extractDue(String sentence) {
    final patterns = [
      RegExp(r'\b(today|tomorrow|next\s+week|this\s+week|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b', caseSensitive: false),
      RegExp(r'\b\d{1,2}[/-]\d{1,2}([/-]\d{2,4})?\b'),
      RegExp(r'\b\d{1,2}:\d{2}\s?(am|pm)?\b', caseSensitive: false),
      RegExp(r'\b\d{1,2}\s?(am|pm)\b', caseSensitive: false),
      RegExp(r'\bby\s+[^,.!?]+', caseSensitive: false),
      RegExp(r'\bbefore\s+[^,.!?]+', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final m = pattern.firstMatch(sentence);
      if (m != null) return m.group(0) ?? 'Not specified';
    }
    return 'Not specified';
  }

  String _detectCategory(String sentence) {
    final s = sentence.toLowerCase();
    if (RegExp(r'invoice|budget|payment|tax|audit|account').hasMatch(s)) return 'Finance';
    if (RegExp(r'client|proposal|lead|contract|pipeline').hasMatch(s)) return 'Sales';
    if (RegExp(r'deploy|bug|release|api|backend|frontend').hasMatch(s)) return 'Engineering';
    if (RegExp(r'vendor|logistics|procurement|approval|process').hasMatch(s)) return 'Operations';
    if (RegExp(r'interview|hiring|onboard|policy|candidate').hasMatch(s)) return 'HR';
    return 'General';
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'finance':
        return const Color(0xFF9C4221);
      case 'sales':
        return const Color(0xFF2B6CB0);
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

  Widget _sectionCard({
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A302C21),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F3EF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF0B5D4B)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6C6A63))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF3D9), Color(0xFFF3EFE6), Color(0xFFE6F1EC)],
          ),
        ),
        child: SafeArea(
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
                  boxShadow: const [
                    BoxShadow(color: Color(0x330E2A25), blurRadius: 20, offset: Offset(0, 10)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Meeting Summarizer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Record, transcribe, extract owners and export to markdown.',
                      style: TextStyle(color: Color(0xFFE3FFF6), fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(_isRecording ? 'Recording Live' : 'Recorder Ready'),
                          avatar: Icon(
                            _isRecording ? Icons.mic : Icons.mic_none,
                            size: 16,
                            color: const Color(0xFF0B5D4B),
                          ),
                          backgroundColor: Colors.white,
                        ),
                        Chip(
                          label: Text('${_items.length} Action Items'),
                          avatar: const Icon(Icons.task_alt, size: 16, color: Color(0xFF0B5D4B)),
                          backgroundColor: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _sectionCard(
                icon: Icons.vpn_key_outlined,
                title: 'Authentication',
                subtitle: 'Used for transcription and AI extraction',
                children: [
                  TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'OpenAI API Key',
                      hintText: 'sk-...',
                    ),
                  ),
                ],
              ),
              _sectionCard(
                icon: Icons.mic_external_on_outlined,
                title: 'Audio Capture',
                subtitle: 'Record and transcribe the meeting',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isBusy || _isRecording ? null : _startRecording,
                          icon: const Icon(Icons.mic),
                          label: const Text('Start'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _isBusy || !_isRecording ? null : _stopRecording,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Stop'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isBusy ? null : _transcribeAudio,
                          icon: const Icon(Icons.graphic_eq),
                          label: const Text('Transcribe'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFCF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDACFB9)),
                    ),
                    child: Text('Status: $_status', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  if (_audioPath != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Audio File: $_audioPath',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              _sectionCard(
                icon: Icons.subject_outlined,
                title: 'Transcript',
                subtitle: 'Review and edit before extraction',
                children: [
                  TextField(
                    controller: _transcriptController,
                    minLines: 7,
                    maxLines: 12,
                    decoration: const InputDecoration(
                      hintText: 'Transcript appears here or paste manually',
                    ),
                  ),
                ],
              ),
              _sectionCard(
                icon: Icons.auto_awesome_outlined,
                title: 'Action Extraction',
                subtitle: 'Choose model-based or rule-based mode',
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'ai',
                        label: Text('AI'),
                        icon: Icon(Icons.bolt_outlined),
                      ),
                      ButtonSegment<String>(
                        value: 'rule',
                        label: Text('Rule'),
                        icon: Icon(Icons.rule_outlined),
                      ),
                    ],
                    selected: {_extractMode},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _extractMode = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isBusy
                          ? null
                          : () async {
                              if (_extractMode == 'ai') {
                                await _extractActionsWithAi();
                              } else {
                                _extractActionsRuleBased();
                              }
                            },
                      icon: const Icon(Icons.play_arrow_outlined),
                      label: Text(_extractMode == 'ai' ? 'Run AI Extraction' : 'Run Rule Extraction'),
                    ),
                  ),
                ],
              ),
              _sectionCard(
                icon: Icons.checklist_rtl_outlined,
                title: 'Action Items',
                subtitle: 'Owners, due dates and categories',
                children: [
                  if (_items.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFCF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDACFB9)),
                      ),
                      child: const Text('No action items yet. Run extraction after transcript is ready.'),
                    )
                  else
                    ..._items.map((item) {
                      final accent = _categoryColor(item.category);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD8CEBC)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 6,
                              height: 54,
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Owner: ${item.owner} | Due: ${item.due}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF54514A)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.category,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
              _sectionCard(
                icon: Icons.file_download_outlined,
                title: 'Markdown Export',
                subtitle: 'Generate and store meeting summary locally',
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isBusy ? null : _generateAndExportMarkdown,
                      icon: const Icon(Icons.download_for_offline_outlined),
                      label: const Text('Generate + Export Markdown'),
                    ),
                  ),
                  if (_lastExportPath.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Saved at: $_lastExportPath',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: _markdownController,
                    minLines: 6,
                    maxLines: 14,
                    decoration: const InputDecoration(
                      labelText: 'Markdown Preview',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _normalizeString(dynamic value, {required String fallback}) {
  if (value == null) return fallback;
  final asString = value.toString().trim();
  return asString.isEmpty ? fallback : asString;
}

String _extractOutputText(Map<String, dynamic> json) {
  final outputText = json['output_text'];
  if (outputText is String && outputText.trim().isNotEmpty) return outputText;

  final output = json['output'];
  if (output is List) {
    final parts = <String>[];
    for (final block in output) {
      if (block is! Map<String, dynamic>) continue;
      final content = block['content'];
      if (content is! List) continue;
      for (final item in content) {
        if (item is! Map<String, dynamic>) continue;
        final text = item['text'];
        if (text is String && text.trim().isNotEmpty) {
          parts.add(text);
        }
      }
    }
    return parts.join('\n').trim();
  }
  return '';
}
