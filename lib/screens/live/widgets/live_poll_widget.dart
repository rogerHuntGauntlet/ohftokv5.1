import 'package:flutter/material.dart';
import '../../../services/interactive/interactive_stream_service.dart';
import 'package:provider/provider.dart';
import '../../../services/social/auth_service.dart';

class LivePollWidget extends StatefulWidget {
  final String streamId;
  final bool isHost;

  const LivePollWidget({
    Key? key,
    required this.streamId,
    required this.isHost,
  }) : super(key: key);

  @override
  State<LivePollWidget> createState() => _LivePollWidgetState();
}

class _LivePollWidgetState extends State<LivePollWidget> {
  final InteractiveStreamService _interactiveService = InteractiveStreamService();
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showCreatePollDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Poll'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Question',
                hintText: 'Enter your poll question',
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_optionControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _optionControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Option ${index + 1}',
                          hintText: 'Enter option ${index + 1}',
                        ),
                      ),
                    ),
                    if (index >= 2)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          setState(() {
                            _optionControllers.removeAt(index);
                          });
                          Navigator.pop(context);
                          _showCreatePollDialog();
                        },
                      ),
                  ],
                ),
              );
            }),
            if (_optionControllers.length < 4)
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Option'),
                onPressed: () {
                  setState(() {
                    _optionControllers.add(TextEditingController());
                  });
                  Navigator.pop(context);
                  _showCreatePollDialog();
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_questionController.text.isEmpty ||
                  _optionControllers.any((c) => c.text.isEmpty)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields'),
                  ),
                );
                return;
              }

              await _interactiveService.createPoll(
                widget.streamId,
                _questionController.text,
                _optionControllers.map((c) => c.text).toList(),
              );

              _questionController.clear();
              for (var controller in _optionControllers) {
                controller.clear();
              }

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black.withOpacity(0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Icon(Icons.poll, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Live Polls',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (widget.isHost)
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: _showCreatePollDialog,
                  ),
              ],
            ),
          ),

          // Poll list
          StreamBuilder<List<Poll>>(
            stream: _interactiveService.getPolls(widget.streamId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Error loading polls',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final polls = snapshot.data!;
              if (polls.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No active polls',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: polls.length,
                itemBuilder: (context, index) {
                  final poll = polls[index];
                  final totalVotes = poll.votes.values.fold<int>(0, (a, b) => a + b);

                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                poll.question,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (widget.isHost && poll.isActive)
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => _interactiveService.endPoll(
                                  widget.streamId,
                                  poll.id,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...poll.options.map((option) {
                          final votes = poll.votes[option] ?? 0;
                          final percentage = totalVotes > 0
                              ? (votes / totalVotes * 100).toStringAsFixed(1)
                              : '0.0';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: poll.isActive
                                  ? () {
                                      final userId = context.read<AuthService>().currentUser?.uid;
                                      if (userId != null) {
                                        _interactiveService.votePoll(
                                          widget.streamId,
                                          poll.id,
                                          option,
                                          userId,
                                        );
                                      }
                                    }
                                  : null,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.white.withOpacity(0.1),
                                ),
                                child: Stack(
                                  children: [
                                    // Progress bar
                                    FractionallySizedBox(
                                      widthFactor: totalVotes > 0 ? votes / totalVotes : 0,
                                      child: Container(
                                        height: 40,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          color: Colors.blue.withOpacity(0.3),
                                        ),
                                      ),
                                    ),
                                    // Option text and percentage
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              option,
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                          ),
                                          Text(
                                            '$percentage%',
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        if (!poll.isActive)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Poll ended',
                              style: TextStyle(
                                color: Colors.white70,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
} 