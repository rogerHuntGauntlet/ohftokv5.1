import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ProfileCompletionCard extends StatelessWidget {
  const ProfileCompletionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return FutureBuilder<int>(
      future: authService.getProfileCompletion(authService.currentUser!.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final completion = snapshot.data!;
        if (completion == 100) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline),
                    const SizedBox(width: 8),
                    Text(
                      'Complete Your Profile',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: completion / 100,
                  backgroundColor: Colors.grey[200],
                ),
                const SizedBox(height: 8),
                Text(
                  '$completion% Complete',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    if (completion < 40)
                      ActionChip(
                        avatar: const Icon(Icons.add_a_photo, size: 16),
                        label: const Text('Add Profile Picture'),
                        onPressed: () {
                          // Navigate to profile picture upload
                          Navigator.of(context).pushNamed('/profile/edit');
                        },
                      ),
                    if (completion < 60)
                      ActionChip(
                        avatar: const Icon(Icons.edit, size: 16),
                        label: const Text('Add Bio'),
                        onPressed: () {
                          // Navigate to bio edit
                          Navigator.of(context).pushNamed('/profile/edit');
                        },
                      ),
                    if (completion < 80)
                      ActionChip(
                        avatar: const Icon(Icons.interests, size: 16),
                        label: const Text('Select Interests'),
                        onPressed: () {
                          // Navigate to interests selection
                          Navigator.of(context).pushNamed('/profile/interests');
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 