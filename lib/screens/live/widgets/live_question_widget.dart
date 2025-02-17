import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/live/live_question.dart';
import '../../../services/live/live_question_service.dart';
import '../../../services/social/auth_service.dart';

class LiveQuestionWidget extends StatefulWidget {
  final String streamId;
  final LiveQuestionService questionService;
  final bool isHost;

  const LiveQuestionWidget({
    Key? key,
    required this.streamId,
    required this.questionService,
    required this.isHost,
  }) : super(key: key);

  @override
  State<LiveQuestionWidget> createState() => _LiveQuestionWidgetState();
}

class _LiveQuestionWidgetState extends State<LiveQuestionWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _askQuestion() async {
    if (_questionController.text.isEmpty) return;

    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    try {
      await widget.questionService.askQuestion(
        streamId: widget.streamId,
        userId: user.uid,
        userDisplayName: user.displayName ?? 'Anonymous',
        userProfileImage: user.photoURL,
        question: _questionController.text,
      );

      _questionController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error asking question: $e')),
        );
      }
    }
  }

  Future<void> _answerQuestion(LiveQuestion question) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Answer Question'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question: ${question.question}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _answerController,
              decoration: const InputDecoration(
                labelText: 'Your Answer',
                hintText: 'Type your answer here',
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

              try {
                await widget.questionService.answerQuestion(
                  questionId: question.id,
                  answer: _answerController.text,
                );

                _answerController.clear();
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error answering question: $e')),
                  );
                }
              }
            },
            child: const Text('Answer'),
          ),
        ],
      ),
    );
  }

  Future<void> _upvoteQuestion(LiveQuestion question) async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    try {
      await widget.questionService.upvoteQuestion(
        questionId: question.id,
        userId: user.uid,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error upvoting question: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Q&A Header
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (!widget.isHost)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Ask a Question'),
                          content: TextField(
                            controller: _questionController,
                            decoration: const InputDecoration(
                              labelText: 'Your Question',
                              hintText: 'Type your question here',
                            ),
                            maxLines: 3,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                _askQuestion();
                                Navigator.pop(context);
                              },
                              child: const Text('Ask'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Unanswered'),
              Tab(text: 'Answered'),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Unanswered questions
                StreamBuilder<List<LiveQuestion>>(
                  stream: widget.questionService.getUnansweredQuestions(widget.streamId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final questions = snapshot.data!;
                    if (questions.isEmpty) {
                      return const Center(
                        child: Text(
                          'No questions yet',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: questions.length,
                      itemBuilder: (context, index) {
                        final question = questions[index];
                        return _QuestionCard(
                          question: question,
                          isHost: widget.isHost,
                          onUpvote: () => _upvoteQuestion(question),
                          onAnswer: widget.isHost
                              ? () => _answerQuestion(question)
                              : null,
                        );
                      },
                    );
                  },
                ),

                // Answered questions
                StreamBuilder<List<LiveQuestion>>(
                  stream: widget.questionService.getAnsweredQuestions(widget.streamId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final questions = snapshot.data!;
                    if (questions.isEmpty) {
                      return const Center(
                        child: Text(
                          'No answered questions',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: questions.length,
                      itemBuilder: (context, index) {
                        final question = questions[index];
                        return _QuestionCard(
                          question: question,
                          isHost: widget.isHost,
                          onUpvote: () => _upvoteQuestion(question),
                          onAnswer: null,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final LiveQuestion question;
  final bool isHost;
  final VoidCallback onUpvote;
  final VoidCallback? onAnswer;

  const _QuestionCard({
    required this.question,
    required this.isHost,
    required this.onUpvote,
    this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthService>().currentUser;
    final hasUpvoted = user != null && question.upvoterIds.contains(user.uid);

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundImage: question.userProfileImage != null
                      ? NetworkImage(question.userProfileImage!)
                      : null,
                  child: question.userProfileImage == null
                      ? Text(question.userDisplayName[0])
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.userDisplayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(question.question),
                      if (question.isAnswered && question.answer != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Answer:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(question.answer!),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    hasUpvoted ? Icons.thumb_up : Icons.thumb_up_outlined,
                    color: hasUpvoted ? Colors.blue : null,
                  ),
                  onPressed: onUpvote,
                ),
                Text(question.upvotes.toString()),
                const Spacer(),
                if (onAnswer != null)
                  TextButton.icon(
                    onPressed: onAnswer,
                    icon: const Icon(Icons.question_answer),
                    label: const Text('Answer'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 