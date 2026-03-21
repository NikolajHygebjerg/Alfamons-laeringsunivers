class Task {
  final String id;
  final String title;
  final String? description;
  final String mode; // 'fixed' | 'counter'
  final int? pointsFixed;
  final int? pointsPerUnit;
  /// Valgfri emoji valgt af voksen (ét grafem).
  final String? emoji;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.mode,
    this.pointsFixed,
    this.pointsPerUnit,
    this.emoji,
  });

  /// Til visning når ingen emoji er sat (barnets skærm m.m.).
  String get displayEmoji {
    final e = emoji?.trim();
    if (e != null && e.isNotEmpty) return e;
    return '📋';
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    final rawEmoji = json['emoji'];
    final emojiStr = rawEmoji is String ? rawEmoji.trim() : null;
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      mode: json['mode'] as String,
      pointsFixed: _toInt(json['points_fixed']),
      pointsPerUnit: _toInt(json['points_per_unit']),
      emoji: (emojiStr != null && emojiStr.isNotEmpty) ? emojiStr : null,
    );
  }
}

class TaskInstance {
  final String id;
  final String taskId;
  final String kidId;
  final String date;
  final String? dueTime;
  final String status; // 'pending' | 'completed' | 'needs_approval' | 'approved'
  final Task task;
  /// Hvor mange gange opgaven skal løses denne dag (standard 1).
  final int requiredCompletions;
  /// Hvor mange gange der allerede er gennemført (godkendt/fuldført).
  final int completionsDone;

  TaskInstance({
    required this.id,
    required this.taskId,
    required this.kidId,
    required this.date,
    this.dueTime,
    required this.status,
    required this.task,
    this.requiredCompletions = 1,
    this.completionsDone = 0,
  });

  factory TaskInstance.fromJson(Map<String, dynamic> json) {
    final tasksRaw = json['tasks'];
    final tasksMap = tasksRaw is Map ? Map<String, dynamic>.from(tasksRaw) : <String, dynamic>{};
    tasksMap['id'] ??= json['task_id'];
    return TaskInstance(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      kidId: json['kid_id'] as String,
      date: json['date'] as String,
      dueTime: json['due_time'] as String?,
      status: json['status'] as String,
      task: Task.fromJson(tasksMap),
      requiredCompletions: Task._toInt(json['required_completions']) ?? 1,
      completionsDone: Task._toInt(json['completions_done']) ?? 0,
    );
  }

  bool get isCompleted => status == 'completed' || status == 'approved';

  bool get hasMoreRounds =>
      status == 'pending' && completionsDone < requiredCompletions;
}
