import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/task.dart';
import '../../utils/recurring_task_schedule.dart';

/// Resultat fra planlægnings-dialog (ny eller opdatering af recurring_tasks).
class RecurringScheduleResult {
  final String scheduleMode;
  final List<int>? weekdays;
  final List<String>? specificDatesIso;
  final String dueTime;
  final int perDayCount;

  const RecurringScheduleResult({
    required this.scheduleMode,
    this.weekdays,
    this.specificDatesIso,
    required this.dueTime,
    required this.perDayCount,
  });
}

/// Vælg frekvens: hver dag, udvalgte ugedage, eller konkrete datoer (kalender).
Future<RecurringScheduleResult?> showRecurringTaskScheduleDialog({
  required BuildContext context,
  required Task task,
  Map<String, dynamic>? existingRow,
}) {
  return showDialog<RecurringScheduleResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _RecurringTaskScheduleDialog(
      task: task,
      existingRow: existingRow,
    ),
  );
}

class _RecurringTaskScheduleDialog extends StatefulWidget {
  final Task task;
  final Map<String, dynamic>? existingRow;

  const _RecurringTaskScheduleDialog({
    required this.task,
    this.existingRow,
  });

  @override
  State<_RecurringTaskScheduleDialog> createState() =>
      _RecurringTaskScheduleDialogState();
}

class _RecurringTaskScheduleDialogState
    extends State<_RecurringTaskScheduleDialog> {
  late String _mode;
  final Set<int> _weekdays = {}; // 1–7
  final Set<DateTime> _pickedDates = {};
  late TextEditingController _dueTimeController;
  late TextEditingController _countController;
  DateTime _focusedDay = DateTime.now();
  String? _error;

  static const _dayLabels = [
    (1, 'Man'),
    (2, 'Tir'),
    (3, 'Ons'),
    (4, 'Tor'),
    (5, 'Fre'),
    (6, 'Lør'),
    (7, 'Søn'),
  ];

  @override
  void initState() {
    super.initState();
    final row = widget.existingRow;
    _dueTimeController = TextEditingController(
      text: row?['due_time'] as String? ?? '18:00',
    );
    _countController = TextEditingController(
      text: '${row?['per_day_count'] as int? ?? 1}',
    );

    _mode = row?['schedule_mode'] as String? ??
        RecurringTaskSchedule.modeEveryDay;

    final wd = row?['weekdays'];
    if (wd is List) {
      for (final e in wd) {
        _weekdays.add((e as num).toInt());
      }
    }

    final sd = row?['specific_dates'];
    if (sd is List) {
      for (final e in sd) {
        final s = e.toString().substring(0, 10);
        final p = DateTime.tryParse(s);
        if (p != null) {
          _pickedDates.add(DateTime.utc(p.year, p.month, p.day));
        }
      }
    }
  }

  @override
  void dispose() {
    _dueTimeController.dispose();
    _countController.dispose();
    super.dispose();
  }

  void _setMode(String m) {
    setState(() {
      _mode = m;
      _error = null;
    });
  }

  void _toggleWeekday(int d) {
    setState(() {
      if (_weekdays.contains(d)) {
        _weekdays.remove(d);
      } else {
        _weekdays.add(d);
      }
      _error = null;
    });
  }

  DateTime _normalizeUtc(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  void _submit() {
    final due = _dueTimeController.text.trim();
    if (due.isEmpty) {
      setState(() => _error = 'Angiv et tidspunkt (fx 18:00)');
      return;
    }
    final count = int.tryParse(_countController.text.trim());
    if (count == null || count < 1) {
      setState(() => _error = 'Antal pr. dag skal være mindst 1');
      return;
    }

    if (_mode == RecurringTaskSchedule.modeWeekdays && _weekdays.isEmpty) {
      setState(() => _error = 'Vælg mindst én ugedag, eller skift til "Hver dag".');
      return;
    }

    if (_mode == RecurringTaskSchedule.modeSpecificDates &&
        _pickedDates.isEmpty) {
      setState(
        () => _error = 'Vælg mindst én dato i kalenderen, eller skift til anden frekvens.',
      );
      return;
    }

    List<int>? weekdaysOut;
    List<String>? datesOut;

    if (_mode == RecurringTaskSchedule.modeWeekdays) {
      weekdaysOut = _weekdays.toList()..sort();
    } else if (_mode == RecurringTaskSchedule.modeSpecificDates) {
      final sorted = _pickedDates.toList()
        ..sort((a, b) => a.compareTo(b));
      datesOut = sorted
          .map(
            (d) =>
                '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
          )
          .toList();
    }

    Navigator.of(context).pop(
      RecurringScheduleResult(
        scheduleMode: _mode,
        weekdays: weekdaysOut,
        specificDatesIso: datesOut,
        dueTime: due,
        perDayCount: count,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Plan: ${widget.task.title}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Hvornår skal opgaven vises?',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: RecurringTaskSchedule.modeEveryDay,
                    label: Text('Hver dag'),
                    icon: Icon(Icons.calendar_month, size: 18),
                  ),
                  ButtonSegment(
                    value: RecurringTaskSchedule.modeWeekdays,
                    label: Text('Ugedage'),
                    icon: Icon(Icons.date_range, size: 18),
                  ),
                  ButtonSegment(
                    value: RecurringTaskSchedule.modeSpecificDates,
                    label: Text('Datoer'),
                    icon: Icon(Icons.event, size: 18),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) {
                  if (s.isNotEmpty) _setMode(s.first);
                },
              ),
              const SizedBox(height: 16),
              if (_mode == RecurringTaskSchedule.modeWeekdays) ...[
                const Text('Vælg ugedage (kan kombineres):'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _dayLabels.map((e) {
                    final selected = _weekdays.contains(e.$1);
                    return FilterChip(
                      label: Text(e.$2),
                      selected: selected,
                      onSelected: (_) => _toggleWeekday(e.$1),
                    );
                  }).toList(),
                ),
              ],
              if (_mode == RecurringTaskSchedule.modeSpecificDates) ...[
                const Text('Tryk på datoer for at vælge/fravælge:'),
                const SizedBox(height: 8),
                TableCalendar<void>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2035, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: CalendarFormat.month,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  selectedDayPredicate: (day) =>
                      _pickedDates.contains(_normalizeUtc(day)),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      final n = _normalizeUtc(selectedDay);
                      if (_pickedDates.contains(n)) {
                        _pickedDates.remove(n);
                      } else {
                        _pickedDates.add(n);
                      }
                      _focusedDay = focusedDay;
                      _error = null;
                    });
                  },
                  onPageChanged: (focused) {
                    setState(() => _focusedDay = focused);
                  },
                  calendarStyle: const CalendarStyle(
                    outsideDaysVisible: false,
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _dueTimeController,
                decoration: const InputDecoration(
                  labelText: 'Senest (klokkeslæt)',
                  hintText: '18:00',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _countController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Antal pr. dag',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuller'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF5A1A0D),
          ),
          child: const Text('Gem'),
        ),
      ],
    );
  }
}
