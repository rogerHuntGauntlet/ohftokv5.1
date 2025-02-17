import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/live/scheduled_stream_service.dart';
import 'edit_stream_dialog.dart';

class ScheduleStreamDialog extends StatefulWidget {
  final ScheduledStreamService streamService;

  const ScheduleStreamDialog({
    Key? key,
    required this.streamService,
  }) : super(key: key);

  @override
  State<ScheduleStreamDialog> createState() => _ScheduleStreamDialogState();
}

class _ScheduleStreamDialogState extends State<ScheduleStreamDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  late DateTime _scheduledStart;
  late Duration _duration;
  bool _isPublic = true;
  bool _isRecurring = false;
  String _recurrenceType = 'weekly';
  int _recurrenceCount = 1;

  @override
  void initState() {
    super.initState();
    _scheduledStart = DateTime.now().add(const Duration(hours: 1));
    _duration = const Duration(hours: 1);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledStart,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null) return;

    if (!context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledStart),
    );

    if (time == null) return;

    setState(() {
      _scheduledStart = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _selectDuration(BuildContext context) async {
    final result = await showDialog<Duration>(
      context: context,
      builder: (context) => DurationPickerDialog(
        initialDuration: _duration,
      ),
    );

    if (result != null) {
      setState(() {
        _duration = result;
      });
    }
  }

  Future<void> _scheduleStream() async {
    try {
      if (_titleController.text.isEmpty) {
        throw 'Title is required';
      }

      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      final recurrenceMetadata = _isRecurring
          ? {
              'type': _recurrenceType,
              'count': _recurrenceCount,
            }
          : null;

      await widget.streamService.createScheduledStream(
        title: _titleController.text,
        description: _descriptionController.text,
        scheduledStart: _scheduledStart,
        duration: _duration,
        tags: tags,
        isPublic: _isPublic,
        recurrence: _isRecurring ? _recurrenceType : null,
        recurrenceMetadata: recurrenceMetadata,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y \'at\' h:mm a');
    final durationText = _duration.inHours > 0
        ? '${_duration.inHours}h ${_duration.inMinutes % 60}m'
        : '${_duration.inMinutes}m';

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Schedule New Stream',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter stream title',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter stream description',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Schedule'),
                        subtitle: Text(dateFormat.format(_scheduledStart)),
                        trailing: TextButton(
                          onPressed: () => _selectDateTime(context),
                          child: const Text('Change'),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Duration'),
                        subtitle: Text(durationText),
                        trailing: TextButton(
                          onPressed: () => _selectDuration(context),
                          child: const Text('Change'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    hintText: 'Enter tags separated by commas',
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Public Stream'),
                  subtitle: const Text(
                    'Make this stream visible to everyone',
                  ),
                  value: _isPublic,
                  onChanged: (value) => setState(() => _isPublic = value),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Recurring Stream'),
                  subtitle: const Text(
                    'Schedule this stream to repeat',
                  ),
                  value: _isRecurring,
                  onChanged: (value) => setState(() => _isRecurring = value),
                ),
                if (_isRecurring) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Recurrence',
                          ),
                          value: _recurrenceType,
                          items: const [
                            DropdownMenuItem(
                              value: 'daily',
                              child: Text('Daily'),
                            ),
                            DropdownMenuItem(
                              value: 'weekly',
                              child: Text('Weekly'),
                            ),
                            DropdownMenuItem(
                              value: 'monthly',
                              child: Text('Monthly'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _recurrenceType = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Number of Occurrences',
                          ),
                          value: _recurrenceCount,
                          items: List.generate(12, (index) {
                            return DropdownMenuItem(
                              value: index + 1,
                              child: Text('${index + 1}'),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _recurrenceCount = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _scheduleStream,
                      child: const Text('Schedule Stream'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 