class Task {
  final String id;
  final String title;
  final String? description;
  final String mode; // 'fixed' | 'counter'
  final int? pointsFixed;
  final int? pointsPerUnit;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.mode,
    this.pointsFixed,
    this.pointsPerUnit,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      mode: json['mode'] as String,
      pointsFixed: json['points_fixed'] as int?,
      pointsPerUnit: json['points_per_unit'] as int?,
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

  TaskInstance({
    required this.id,
    required this.taskId,
    required this.kidId,
    required this.date,
    this.dueTime,
    required this.status,
    required this.task,
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
    );
  }

  bool get isCompleted => status == 'completed' || status == 'approved';
}
