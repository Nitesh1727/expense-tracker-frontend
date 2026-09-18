import 'package:flutter/material.dart';

/// A two-step calendar dialog (start date, then end date) instead of
/// Flutter's built-in `showDateRangePicker` — that widget's calendar view
/// requires knowing you tap *twice* on one grid to define a range, and its
/// "switch to typing" pencil icon is easy to land on by accident, at which
/// point you're stuck typing a date in a strict format instead of picking
/// one visually. `CalendarDatePicker` (the same widget `showDatePicker` uses
/// internally) is the most familiar date-picking UI on both platforms —
/// clear month arrows, and tapping the header drops into a year grid to
/// jump further back.
///
/// Built as one custom dialog (not two independent `showDatePicker` calls)
/// specifically so the user can move **back** from the end-date step to
/// revisit the start date without cancelling the whole flow — per explicit
/// feedback that people need to be able to change their mind mid-flow, not
/// just start over. Each step also says explicitly what step it is and
/// what happens next, since nothing about a bare calendar communicates
/// "there's a second step coming" on its own.
Future<DateTimeRange?> pickFriendlyDateRange(
  BuildContext context, {
  DateTimeRange? initial,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDialog<DateTimeRange>(
    context: context,
    builder: (context) => _DateRangeStepDialog(initial: initial, firstDate: firstDate, lastDate: lastDate),
  );
}

class _DateRangeStepDialog extends StatefulWidget {
  final DateTimeRange? initial;
  final DateTime firstDate;
  final DateTime lastDate;

  const _DateRangeStepDialog({required this.initial, required this.firstDate, required this.lastDate});

  @override
  State<_DateRangeStepDialog> createState() => _DateRangeStepDialogState();
}

class _DateRangeStepDialogState extends State<_DateRangeStepDialog> {
  late DateTime _start = widget.initial?.start ?? widget.lastDate;
  late DateTime _end = widget.initial?.end ?? widget.lastDate;
  bool _onEndStep = false;

  void _onStartChanged(DateTime date) {
    setState(() {
      _start = date;
      // Keep `end` valid if it's now before the newly-picked start — e.g.
      // the user went Back and moved the start date later than the end
      // date they'd already picked.
      if (_end.isBefore(_start)) _end = _start;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      // Header text (3 lines) + a fixed-height calendar + footer buttons
      // easily exceeds a short landscape viewport, and Dialog doesn't scroll
      // its content on its own. Capping the dialog's height and wrapping in
      // a scroll view is a no-op in the common (portrait, enough room) case
      // and just prevents an overflow crash in the tighter ones.
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: SingleChildScrollView(
          child: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _onEndStep ? 'Step 2 of 2' : 'Step 1 of 2',
                    style: textTheme.labelLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(_onEndStep ? 'Select end date' : 'Select start date', style: textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    _onEndStep
                        ? "You can go back if you'd like to change the start date."
                        : "You'll pick an end date next — take your time.",
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 380,
              // Keyed by step so switching steps rebuilds the calendar
              // fresh at the right initial month instead of reusing whatever
              // month the *other* step's picker happened to be scrolled to.
              child: _onEndStep
                  ? CalendarDatePicker(
                      key: const ValueKey('end'),
                      initialDate: _end,
                      firstDate: _start,
                      lastDate: widget.lastDate,
                      onDateChanged: (date) => setState(() => _end = date),
                    )
                  : CalendarDatePicker(
                      key: const ValueKey('start'),
                      initialDate: _start,
                      firstDate: widget.firstDate,
                      lastDate: widget.lastDate,
                      onDateChanged: _onStartChanged,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const Spacer(),
                  if (_onEndStep)
                    TextButton(onPressed: () => setState(() => _onEndStep = false), child: const Text('Back')),
                  TextButton(
                    onPressed: () {
                      if (_onEndStep) {
                        Navigator.of(context).pop(DateTimeRange(start: _start, end: _end));
                      } else {
                        setState(() => _onEndStep = true);
                      }
                    },
                    child: Text(_onEndStep ? 'Done' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}
