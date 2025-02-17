import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TitleSection extends StatelessWidget {
  final String? currentTitle;
  final String movieId;
  final bool isReadOnly;
  final Function(String) onTitleChanged;

  const TitleSection({
    Key? key,
    required this.currentTitle,
    required this.movieId,
    required this.isReadOnly,
    required this.onTitleChanged,
  }) : super(key: key);

  Future<void> _showTitleDialog(BuildContext context) async {
    final textController = TextEditingController(text: currentTitle);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(currentTitle == null ? 'Create Movie Title' : 'Edit Movie Title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                hintText: 'Enter a title for your movie...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newTitle = textController.text.trim();
              if (newTitle.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('movies')
                    .doc(movieId)
                    .update({'title': newTitle});
                onTitleChanged(newTitle);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: isReadOnly ? null : () => _showTitleDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  currentTitle ?? 'Untitled Movie',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
          ),
          if (!isReadOnly)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showTitleDialog(context),
              tooltip: 'Edit Title',
            ),
        ],
      ),
    );
  }
}
