import 'package:flutter/material.dart';
import '../../../services/interactive/interactive_stream_service.dart';
import 'package:provider/provider.dart';
import '../../../services/social/auth_service.dart';

class LiveQAWidget extends StatefulWidget {
  final String streamId;
  final bool isHost;

  const LiveQAWidget({
    Key? key,
    required this.streamId,
    required this.isHost,
  }) : super(key: key);

  @override
  State<LiveQAWidget> createState() => _LiveQAWidgetState();
}

class _LiveQAWidgetState extends State<LiveQAWidget> {
  final InteractiveStreamService _interactiveService = InteractiveStreamService();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  void _showAnswerDialog(Question question) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Answer Question'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question: ${question.text}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _answerController,
              decoration: const InputDecoration(
                labelText: 'Answer',
                hintText: 'Enter your answer',
              ),
              maxLines: 3,
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
              if (_answerController.text.isEmpty) return;

              await _interactiveService.answerQuestion(
                widget.streamId,
                question.id,
                _answerController.text,
              );

              _answerController.clear();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Submit'),
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
                const Icon(Icons.question_answer, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Q&A',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (!widget.isHost)
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Ask a Question'),
                          content: TextField(
                            controller: _questionController,
                            decoration: const InputDecoration(
                              labelText: 'Question',
                              hintText: 'Enter your question',
                            ),
                            maxLines: 2,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () async {
                                if (_questionController.text.isEmpty) return;

                                final user = context.read<AuthService>().currentUser;
                                if (user == null) return;

                                await _interactiveService.askQuestion(
                                  widget.streamId,
                                  user.uid,
                                  user.displayName ?? 'Anonymous',
                                  _questionController.text,
                                );

                                _questionController.clear();
                                if (context.mounted) Navigator.pop(context);
                              },
                              child: const Text('Submit'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          // Questions list
          StreamBuilder<List<Question>>(
            stream: _interactiveService.getQuestions(widget.streamId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Error loading questions',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final questions = snapshot.data!;
              if (questions.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No questions yet',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: questions.length,
                itemBuilder: (context, index) {
                  final question = questions[index];
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    question.userName,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    question.text,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            if (!widget.isHost)
                              IconButton(
                                icon: const Icon(Icons.arrow_upward, color: Colors.white),
                                onPressed: () => _interactiveService.upvoteQuestion(
                                  widget.streamId,
                                  question.id,
                                ),
                              ),
                            Text(
                              question.upvotes.toString(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        if (question.isAnswered && question.answer != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Answer:',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  question.answer!,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ] else if (widget.isHost && !question.isAnswered) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => _showAnswerDialog(question),
                            child: const Text('Answer'),
                          ),
                        ],
                        const Divider(color: Colors.white24),
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