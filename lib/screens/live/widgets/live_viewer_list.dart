import 'package:flutter/material.dart';
import '../../../models/live/live_viewer.dart';
import '../../../services/live/live_viewer_service.dart';

class LiveViewerList extends StatelessWidget {
  final String streamId;
  final LiveViewerService viewerService;

  const LiveViewerList({
    Key? key,
    required this.streamId,
    required this.viewerService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showViewerListDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: StreamBuilder<List<LiveViewer>>(
          stream: viewerService.getActiveViewers(streamId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }

            final viewers = snapshot.data!;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  viewers.length.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showViewerListDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Viewers',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<LiveViewer>>(
                stream: viewerService.getActiveViewers(streamId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final viewers = snapshot.data!;
                  final moderators = viewers.where((v) => v.isModerator).toList();
                  final vips = viewers.where((v) => v.isVIP).toList();
                  final regularViewers = viewers.where(
                    (v) => !v.isModerator && !v.isVIP && !v.isBanned
                  ).toList();

                  return SizedBox(
                    height: 300,
                    child: ListView(
                      children: [
                        if (moderators.isNotEmpty) ...[
                          const _ViewerListHeader(title: 'Moderators'),
                          ...moderators.map((v) => _ViewerListItem(viewer: v)),
                          const Divider(color: Colors.white24),
                        ],
                        if (vips.isNotEmpty) ...[
                          const _ViewerListHeader(title: 'VIPs'),
                          ...vips.map((v) => _ViewerListItem(viewer: v)),
                          const Divider(color: Colors.white24),
                        ],
                        if (regularViewers.isNotEmpty) ...[
                          const _ViewerListHeader(title: 'Viewers'),
                          ...regularViewers.map((v) => _ViewerListItem(viewer: v)),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewerListHeader extends StatelessWidget {
  final String title;

  const _ViewerListHeader({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ViewerListItem extends StatelessWidget {
  final LiveViewer viewer;

  const _ViewerListItem({
    required this.viewer,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: viewer.userProfileImage != null
          ? CircleAvatar(
              backgroundImage: NetworkImage(viewer.userProfileImage!),
            )
          : const CircleAvatar(
              child: Icon(Icons.person),
            ),
      title: Text(
        viewer.userDisplayName,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      trailing: _buildRoleBadge(),
    );
  }

  Widget? _buildRoleBadge() {
    if (viewer.isModerator) {
      return _RoleBadge(
        label: 'MOD',
        color: Colors.blue,
      );
    } else if (viewer.isVIP) {
      return _RoleBadge(
        label: 'VIP',
        color: Colors.purple,
      );
    }
    return null;
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _RoleBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
} 