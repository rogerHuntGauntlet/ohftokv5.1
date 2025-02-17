import 'package:flutter/material.dart';

class DeleteConfirmationModal extends StatefulWidget {
  final Function() onConfirm;

  const DeleteConfirmationModal({
    super.key,
    required this.onConfirm,
  });

  @override
  State<DeleteConfirmationModal> createState() => _DeleteConfirmationModalState();
}

class _DeleteConfirmationModalState extends State<DeleteConfirmationModal> {
  final TextEditingController _confirmDeleteController = TextEditingController();

  @override
  void dispose() {
    _confirmDeleteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Movie'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This action cannot be undone. All scenes and videos will be permanently deleted.',
            style: TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          const Text(
            'Type "confirm" to delete:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmDeleteController,
            decoration: const InputDecoration(
              hintText: 'Type confirm here',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_confirmDeleteController.text.trim().toLowerCase() == 'confirm') {
              Navigator.of(context).pop();
              widget.onConfirm();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please type "confirm" exactly to delete'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
} 