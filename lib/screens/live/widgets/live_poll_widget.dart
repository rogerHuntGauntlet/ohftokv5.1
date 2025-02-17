import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/live/live_poll.dart';
import '../../../services/live/live_poll_service.dart';
import '../../../services/social/auth_service.dart';

class LivePollWidget extends StatefulWidget {
  final String streamId;
  final LivePollService pollService;
  final bool isHost;

  const LivePollWidget({
    Key? key,
    required this.streamId,
    required this.pollService,
    required this.isHost,
  }) : super(key: key);

  @override
  State<LivePollWidget> createState() => _LivePollWidgetState();
}

class _LivePollWidgetState extends State<LivePollWidget> {
  final _questionController = TextEditingController();
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

  Future<void> _createPoll() async {
    if (_questionController.text.isEmpty) return;

    final options = _optionControllers
        .map((c) => c.text)
        .where((text) => text.isNotEmpty)
        .toList();

    if (options.length < 2) return;

    try {
      await widget.pollService.createPoll(
        streamId: widget.streamId,
        question: _questionController.text,
        options: options,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating poll: $e')),
        );
      }
    }
  }

  Future<void> _vote(String pollId, int optionIndex) async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    try {
      await widget.pollService.vote(
        pollId: pollId,
        userId: user.uid,
        optionIndex: optionIndex,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error voting: $e')),
        );
      }
    }
  }

  void _showCreatePollDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Poll'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _questionController,
                decoration: const InputDecoration(
                  labelText: 'Question',
                  hintText: 'Enter your question',
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(_optionControllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _optionControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Option ${index + 1}',
                      hintText: 'Enter option ${index + 1}',
                    ),
                  ),
                );
              }),
              TextButton(
                onPressed: () {
                  setState(() {
                    _optionControllers.add(TextEditingController());
                  });
                },
                child: const Text('Add Option'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _createPoll,
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.isHost)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _showCreatePollDialog,
              child: const Text('Create Poll'),
            ),
          ),
        StreamBuilder<List<LivePoll>>(
          stream: widget.pollService.getActivePolls(widget.streamId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final polls = snapshot.data!;
            if (polls.isEmpty) {
              return const SizedBox.shrink();
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: polls.length,
              itemBuilder: (context, index) {
                final poll = polls[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poll.question,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(poll.options.length, (optionIndex) {
                          final option = poll.options[optionIndex];
                          final voteCount = poll.votes[optionIndex] ?? 0;
                          final totalVotes = poll.votes.values.fold(0, (a, b) => a + b);
                          final percentage = totalVotes > 0
                              ? (voteCount / totalVotes * 100).toStringAsFixed(1)
                              : '0.0';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () => _vote(poll.id, optionIndex),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey.withOpacity(0.1),
                                ),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: totalVotes > 0
                                            ? voteCount / totalVotes
                                            : 0,
                                        backgroundColor: Colors.transparent,
                                        minHeight: 40,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(option),
                                          Text('$percentage%'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
} 