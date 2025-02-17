import 'package:flutter/material.dart';
import '../../../services/interactive/interactive_stream_service.dart';
import 'package:provider/provider.dart';
import '../../../services/social/auth_service.dart';

class LiveStoryPromptWidget extends StatefulWidget {
  final String streamId;
  final bool isHost;

  const LiveStoryPromptWidget({
    Key? key,
    required this.streamId,
    required this.isHost,
  }) : super(key: key);

  @override
  State<LiveStoryPromptWidget> createState() => _LiveStoryPromptWidgetState();
}

class _LiveStoryPromptWidgetState extends State<LiveStoryPromptWidget> {
  final InteractiveStreamService _interactiveService = InteractiveStreamService();
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _responseController = TextEditingController();

  @override
  void dispose() {
    _promptController.dispose();
    _responseController.dispose();
    super.dispose();
  }

  void _showCreatePromptDialog() {
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
            onPressed: () async {
              if (_promptController.text.isEmpty) return;

              await _interactiveService.createStoryPrompt(
                widget.streamId,
                _promptController.text,
              );

              _promptController.clear();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showResponseDialog(StoryPrompt prompt) {
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
                labelText: 'Response',
                hintText: 'Enter your response',
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
              if (_responseController.text.isEmpty) return;

              await _interactiveService.submitResponse(
                widget.streamId,
                prompt.id,
                _responseController.text,
              );

              _responseController.clear();
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
                const Icon(Icons.auto_stories, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Story Prompts',
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
                    onPressed: _showCreatePromptDialog,
                  ),
              ],
            ),
          ),

          // Prompts list
          StreamBuilder<List<StoryPrompt>>(
            stream: _interactiveService.getStoryPrompts(widget.streamId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Error loading prompts',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final prompts = snapshot.data!;
              if (prompts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No story prompts yet',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: prompts.length,
                itemBuilder: (context, index) {
                  final prompt = prompts[index];
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prompt.prompt,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (prompt.responses.isNotEmpty) ...[
                          const Text(
                            'Responses:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...prompt.responses.map((response) {
                            final isSelected = response == prompt.selectedResponseId;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(color: Colors.blue)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      response,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  if (widget.isHost &&
                                      prompt.isActive &&
                                      !isSelected)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                        color: Colors.white,
                                      ),
                                      onPressed: () => _interactiveService
                                          .selectResponse(
                                        widget.streamId,
                                        prompt.id,
                                        response,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                        if (prompt.isActive && !widget.isHost)
                          TextButton.icon(
                            icon: const Icon(Icons.reply),
                            label: const Text('Respond'),
                            onPressed: () => _showResponseDialog(prompt),
                          ),
                        if (!prompt.isActive)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Prompt closed',
                              style: TextStyle(
                                color: Colors.white70,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
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