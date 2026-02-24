import '../utils/string_utils.dart';

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
      title: normalizeString(map['title'], fallback: 'Untitled task'),
      owner: normalizeString(map['owner'], fallback: 'Unassigned'),
      due: normalizeString(map['due'], fallback: 'Not specified'),
      category: normalizeString(map['category'], fallback: 'General'),
    );
  }

  Map<String, String> toMap() {
    return {'title': title, 'owner': owner, 'due': due, 'category': category};
  }

  ActionItem copyWith({
    String? title,
    String? owner,
    String? due,
    String? category,
  }) {
    return ActionItem(
      title: title ?? this.title,
      owner: owner ?? this.owner,
      due: due ?? this.due,
      category: category ?? this.category,
    );
  }
}
