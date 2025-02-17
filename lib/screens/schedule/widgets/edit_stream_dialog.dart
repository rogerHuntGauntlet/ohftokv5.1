import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/live/scheduled_stream.dart';
import '../../../services/live/scheduled_stream_service.dart';

class EditStreamDialog extends StatefulWidget {
  final ScheduledStream stream;
  final ScheduledStreamService streamService;

  const EditStreamDialog({
    Key? key,
    required this.stream,
    required this.streamService,
  }) : super(key: key);

  @override
  State<EditStreamDialog> createState() => _EditStreamDialogState();
}

class _EditStreamDialogState extends State<EditStreamDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;
  late DateTime _scheduledStart;
  late Duration _duration;
  late bool _isPublic;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.stream.title);
    _descriptionController = TextEditingController(text: widget.stream.description);
    _tagsController = TextEditingController(
      text: widget.stream.tags.join(', '),
    );
    _scheduledStart = widget.stream.scheduledStart;
    _duration = widget.stream.duration;
    _isPublic = widget.stream.isPublic;
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

  Future<void> _saveChanges() async {
    try {
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      await widget.streamService.updateScheduledStream(
        streamId: widget.stream.id,
        title: _titleController.text,
        description: _descriptionController.text,
        scheduledStart: _scheduledStart,
        duration: _duration,
        tags: tags,
        isPublic: _isPublic,
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Stream',
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
                    onPressed: _saveChanges,
                    child: const Text('Save Changes'),
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

class DurationPickerDialog extends StatefulWidget {
  final Duration initialDuration;

  const DurationPickerDialog({
    Key? key,
    required this.initialDuration,
  }) : super(key: key);

  @override
  State<DurationPickerDialog> createState() => _DurationPickerDialogState();
}

class _DurationPickerDialogState extends State<DurationPickerDialog> {
  late int _hours;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _hours = widget.initialDuration.inHours;
    _minutes = widget.initialDuration.inMinutes % 60;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Duration',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    const Text('Hours'),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        controller: TextEditingController(
                          text: _hours.toString(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _hours = int.tryParse(value) ?? 0;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    const Text('Minutes'),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        controller: TextEditingController(
                          text: _minutes.toString(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _minutes = int.tryParse(value) ?? 0;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
                  onPressed: () {
                    Navigator.of(context).pop(
                      Duration(
                        hours: _hours,
                        minutes: _minutes,
                      ),
                    );
                  },
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 