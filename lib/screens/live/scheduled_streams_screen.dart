import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/live/scheduled_stream_service.dart';
import '../../services/social/auth_service.dart';
import 'live_stream_screen.dart';

class ScheduledStreamsScreen extends StatefulWidget {
  const ScheduledStreamsScreen({Key? key}) : super(key: key);

  @override
  State<ScheduledStreamsScreen> createState() => _ScheduledStreamsScreenState();
}

class _ScheduledStreamsScreenState extends State<ScheduledStreamsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _startNewStream() {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LiveStreamScreen(
          streamId: DateTime.now().millisecondsSinceEpoch.toString(),
          isHost: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Streams'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Live Now'),
            Tab(text: 'My Streams'),
            Tab(text: 'Following'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _startNewStream,
            tooltip: 'Start Streaming',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Live Now Tab
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.live_tv,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Live Streams',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _startNewStream,
                  child: const Text('Start Streaming'),
                ),
              ],
            ),
          ),
          
          // My Streams Tab
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.movie,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Streams Yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _startNewStream,
                  child: const Text('Create Your First Stream'),
                ),
              ],
            ),
          ),
          
          // Following Tab
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Followed Streams',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Navigate to discover streamers
                  },
                  child: const Text('Find Streamers'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 