import '../../../core/utils/dates.dart';

class TaskItem {
  const TaskItem({
    required this.id,
    required this.boardId,
    required this.title,
    this.parentId,
    this.contactId,
    this.done = false,
    this.dueDate,
    this.position = 0,
    this.templateKey,
    this.boardName,
  });

  final String id;
  final String boardId;
  final String title;
  final String? parentId;
  final String? contactId;
  final bool done;
  final DateTime? dueDate;
  final double position;
  final String? templateKey;
  final String? boardName;

  bool isOverdue({DateTime? now}) => !done && dueDate != null && daysUntil(dueDate!, now: now) < 0;

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final board = json['boards'];
    return TaskItem(
      id: json['id'] as String,
      boardId: json['board_id'] as String,
      title: json['title'] as String? ?? '',
      parentId: json['parent_id'] as String?,
      contactId: json['contact_id'] as String?,
      done: json['done'] as bool? ?? false,
      dueDate: parseDate(json['due_date']),
      position: (json['position'] as num?)?.toDouble() ?? 0,
      templateKey: json['template_key'] as String?,
      boardName: board is Map<String, dynamic> ? board['name'] as String? : null,
    );
  }

  Map<String, dynamic> toInsert() => {
        'id': id,
        'board_id': boardId,
        'title': title,
        'parent_id': parentId,
        'contact_id': contactId,
        'done': done,
        'due_date': formatSqlDate(dueDate),
        'position': position,
        'template_key': templateKey,
      };

  TaskItem copyWith({
    String? title,
    bool? done,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? contactId,
    bool clearContact = false,
    double? position,
  }) =>
      TaskItem(
        id: id,
        boardId: boardId,
        title: title ?? this.title,
        parentId: parentId,
        contactId: clearContact ? null : (contactId ?? this.contactId),
        done: done ?? this.done,
        dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
        position: position ?? this.position,
        templateKey: templateKey,
        boardName: boardName,
      );
}
