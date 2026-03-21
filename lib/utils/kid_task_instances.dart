import '../models/task.dart';
import 'recurring_task_schedule.dart';

/// `task_id` som stadig har tildeling og gælder på [date].
Set<String> activeRecurringTaskIdsForDate(
  List<dynamic> recurringRows,
  DateTime date,
) {
  final ids = <String>{};
  for (final rt in recurringRows) {
    final row = Map<String, dynamic>.from(rt as Map);
    if (!RecurringTaskSchedule.appliesToDate(row, date)) continue;
    ids.add(row['task_id'] as String);
  }
  return ids;
}

int _instanceDisplayPriority(TaskInstance ti) {
  if (ti.status == 'pending' || ti.status == 'needs_approval') return 100;
  if (ti.status == 'approved' || ti.status == 'completed') return 50;
  return 0;
}

/// Fjerner "forældreløse" instanser (ingen recurring længere) og samler max én pr. opgave.
List<TaskInstance> filterAndDedupeInstancesForActiveRecurring(
  List<TaskInstance> instances,
  Set<String> activeTaskIds,
) {
  final filtered =
      instances.where((i) => activeTaskIds.contains(i.taskId)).toList();

  final byTask = <String, TaskInstance>{};
  for (final ti in filtered) {
    final cur = byTask[ti.taskId];
    if (cur == null) {
      byTask[ti.taskId] = ti;
      continue;
    }
    final pNew = _instanceDisplayPriority(ti);
    final pOld = _instanceDisplayPriority(cur);
    if (pNew > pOld) {
      byTask[ti.taskId] = ti;
    } else if (pNew == pOld) {
      if (ti.completionsDone > cur.completionsDone) {
        byTask[ti.taskId] = ti;
      } else if (ti.completionsDone == cur.completionsDone &&
          ti.id.compareTo(cur.id) < 0) {
        byTask[ti.taskId] = ti;
      }
    }
  }

  final out = byTask.values.toList();
  out.sort((a, b) {
    final ta = a.dueTime ?? '';
    final tb = b.dueTime ?? '';
    final c = ta.compareTo(tb);
    if (c != 0) return c;
    return a.task.title.compareTo(b.task.title);
  });
  return out;
}
