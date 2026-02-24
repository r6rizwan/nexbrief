import '../utils/string_utils.dart';
import 'action_item.dart';

class MeetingHistoryEntry {
  MeetingHistoryEntry({
    required this.id,
    required this.createdAtIso,
    required this.transcript,
    required this.summaryKeyPoints,
    required this.summaryDecisions,
    required this.summaryRisks,
    required this.summaryNextSteps,
    required this.actionItems,
    required this.markdownPath,
  });

  final String id;
  final String createdAtIso;
  final String transcript;
  final String summaryKeyPoints;
  final String summaryDecisions;
  final String summaryRisks;
  final String summaryNextSteps;
  final List<ActionItem> actionItems;
  final String markdownPath;

  factory MeetingHistoryEntry.fromMap(Map<String, dynamic> map) {
    final rawItems = map['actionItems'];
    final parsedItems = <ActionItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          parsedItems.add(ActionItem.fromMap(item));
        }
      }
    }

    return MeetingHistoryEntry(
      id: normalizeString(
        map['id'],
        fallback: DateTime.now().millisecondsSinceEpoch.toString(),
      ),
      createdAtIso: normalizeString(
        map['createdAtIso'],
        fallback: DateTime.now().toIso8601String(),
      ),
      transcript: normalizeString(map['transcript'], fallback: ''),
      summaryKeyPoints: normalizeString(map['summaryKeyPoints'], fallback: ''),
      summaryDecisions: normalizeString(map['summaryDecisions'], fallback: ''),
      summaryRisks: normalizeString(map['summaryRisks'], fallback: ''),
      summaryNextSteps: normalizeString(map['summaryNextSteps'], fallback: ''),
      actionItems: parsedItems,
      markdownPath: normalizeString(map['markdownPath'], fallback: ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'createdAtIso': createdAtIso,
      'transcript': transcript,
      'summaryKeyPoints': summaryKeyPoints,
      'summaryDecisions': summaryDecisions,
      'summaryRisks': summaryRisks,
      'summaryNextSteps': summaryNextSteps,
      'actionItems': actionItems.map((item) => item.toMap()).toList(),
      'markdownPath': markdownPath,
    };
  }
}
