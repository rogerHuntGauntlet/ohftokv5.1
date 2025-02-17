import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/live/live_story_prompt.dart';
import '../../../services/live/live_story_prompt_service.dart';
import '../../../services/social/auth_service.dart';

class LiveStoryPromptWidget extends StatefulWidget {
  final String streamId;
  final LiveStoryPromptService promptService;
  final bool isHost;

  const LiveStoryPromptWidget({
    Key? key,
    required this.streamId,
    required this.promptService,
    required this.isHost,
  }) : super(key: key);

  @override
  State<LiveStoryPromptWidget> createState() => _LiveStoryPromptWidgetState();
}

class _LiveStoryPromptWidgetState extends State<LiveStoryPromptWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _promptController = TextEditingController();
  final _responseController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promptController.dispose();
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _createPrompt() async {
    if (_promptController.text.isEmpty) return;

    try {
      await widget.promptService.createPrompt(
        streamId: widget.streamId,
        prompt: _promptController.text,
      );

      _promptController.clear();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating prompt: $e')),
        );
      }
    }
  }

  Future<void> _submitResponse(LiveStoryPrompt prompt) async {
    if (_responseController.text.isEmpty) return;

    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    try {
      await widget.promptService.submitResponse(
        promptId: prompt.id,
        userId: user.uid,
        userDisplayName: user.displayName ?? 'Anonymous',
        response: _responseController.text,
      );

      _responseController.clear();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting response: $e')),
        );
      }
    }
  }

  Future<void> _selectResponse(
    LiveStoryPrompt prompt,
    String userId,
    String userDisplayName,
    String response,
  ) async {
    try {
      await widget.promptService.selectResponse(
        promptId: prompt.id,
        userId: userId,
        userDisplayName: userDisplayName,
        response: response,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting response: $e')),
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
          // Story Prompts Header
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Icon(Icons.auto_stories, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Story Prompts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (widget.isHost)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Create Story Prompt'),
                          content: TextField(
                            controller: _promptController,
                            decoration: const InputDecoration(
                              labelText: 'Prompt',
                              hintText: 'Enter your story prompt',
                            ),
                            maxLines: 3,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: _createPrompt,
                              child: const Text('Create'),
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
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Active prompts
                StreamBuilder<List<LiveStoryPrompt>>(
                  stream: widget.promptService.getActivePrompts(widget.streamId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final prompts = snapshot.data!;
                    if (prompts.isEmpty) {
                      return const Center(
                        child: Text(
                          'No active prompts',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: prompts.length,
                      itemBuilder: (context, index) {
                        final prompt = prompts[index];
                        return _StoryPromptCard(
                          prompt: prompt,
                          isHost: widget.isHost,
                          onRespond: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Submit Response'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Prompt: ${prompt.prompt}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: _responseController,
                                      decoration: const InputDecoration(
                                        labelText: 'Your Response',
                                        hintText: 'Type your response here',
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
                                    onPressed: () => _submitResponse(prompt),
                                    child: const Text('Submit'),
                                  ),
                                ],
                              ),
                            );
                          },
                          onSelectResponse: widget.isHost
                              ? (userId, userDisplayName, response) =>
                                  _selectResponse(prompt, userId, userDisplayName, response)
                              : null,
                        );
                      },
                    );
                  },
                ),

                // Completed prompts
                StreamBuilder<List<LiveStoryPrompt>>(
                  stream: widget.promptService.getCompletedPrompts(widget.streamId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final prompts = snapshot.data!;
                    if (prompts.isEmpty) {
                      return const Center(
                        child: Text(
                          'No completed prompts',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: prompts.length,
                      itemBuilder: (context, index) {
                        final prompt = prompts[index];
                        return _StoryPromptCard(
                          prompt: prompt,
                          isHost: widget.isHost,
                          onRespond: null,
                          onSelectResponse: null,
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

class _StoryPromptCard extends StatelessWidget {
  final LiveStoryPrompt prompt;
  final bool isHost;
  final VoidCallback? onRespond;
  final Function(String, String, String)? onSelectResponse;

  const _StoryPromptCard({
    required this.prompt,
    required this.isHost,
    this.onRespond,
    this.onSelectResponse,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              prompt.prompt,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (prompt.responses.isNotEmpty) ...[
              const Text(
                'Responses:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ...prompt.responses.entries.map((entry) {
                final isSelected = entry.key == prompt.selectedUserId;
                return ListTile(
                  title: Text(entry.value),
                  subtitle: Text('by ${prompt.userDisplayName ?? 'Anonymous'}'),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : (onSelectResponse != null
                          ? IconButton(
                              icon: const Icon(Icons.check_circle_outline),
                              onPressed: () => onSelectResponse!(
                                entry.key,
                                prompt.userDisplayName ?? 'Anonymous',
                                entry.value,
                              ),
                            )
                          : null),
                );
              }),
            ],
            if (onRespond != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onRespond,
                  icon: const Icon(Icons.reply),
                  label: const Text('Respond'),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 