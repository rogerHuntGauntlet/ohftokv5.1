import 'package:flutter/material.dart';

class IdeaSection extends StatelessWidget {
  final String movieIdea;

  const IdeaSection({
    Key? key,
    required this.movieIdea,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Movie Idea',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            movieIdea,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const Divider(height: 32),
        ],
      ),
    );
  }
}
