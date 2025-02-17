import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/live/scheduled_stream.dart';
import '../../services/live/scheduled_stream_service.dart';
import '../../services/social/auth_service.dart';
import 'widgets/scheduled_stream_card.dart';
import 'widgets/schedule_stream_dialog.dart';

class ScheduledStreamsScreen extends StatefulWidget {
  const ScheduledStreamsScreen({Key? key}) : super(key: key);

  @override
  State<ScheduledStreamsScreen> createState() => _ScheduledStreamsScreenState();
}

class _ScheduledStreamsScreenState extends State<ScheduledStreamsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScheduledStreamService _streamService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _streamService = ScheduledStreamService();
    _streamService.initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showScheduleDialog() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    await showDialog(
      context: context,
      builder: (context) => ScheduleStreamDialog(
        streamService: _streamService,
        hostId: user.uid,
        hostDisplayName: user.displayName ?? 'Anonymous',
        hostProfileImage: user.photoURL,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) {
      return const Center(child: Text('Please sign in to view scheduled streams'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Streams'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'My Streams'),
            Tab(text: 'Subscribed'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showScheduleDialog,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Upcoming streams
          StreamBuilder<List<ScheduledStream>>(
            stream: _streamService.getUpcomingStreams(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final streams = snapshot.data!;
              if (streams.isEmpty) {
                return const Center(
                  child: Text('No upcoming streams'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: streams.length,
                itemBuilder: (context, index) {
                  final stream = streams[index];
                  return ScheduledStreamCard(
                    stream: stream,
                    streamService: _streamService,
                    isHost: stream.hostId == user.uid,
                    isSubscribed: stream.subscriberIds.contains(user.uid),
                  );
                },
              );
            },
          ),

          // My streams
          StreamBuilder<List<ScheduledStream>>(
            stream: _streamService.getUserScheduledStreams(user.uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final streams = snapshot.data!;
              if (streams.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('You haven\'t scheduled any streams yet'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _showScheduleDialog,
                        child: const Text('Schedule a Stream'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: streams.length,
                itemBuilder: (context, index) {
                  final stream = streams[index];
                  return ScheduledStreamCard(
                    stream: stream,
                    streamService: _streamService,
                    isHost: true,
                    isSubscribed: stream.subscriberIds.contains(user.uid),
                  );
                },
              );
            },
          ),

          // Subscribed streams
          StreamBuilder<List<ScheduledStream>>(
            stream: _streamService.getSubscribedStreams(user.uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final streams = snapshot.data!;
              if (streams.isEmpty) {
                return const Center(
                  child: Text('You haven\'t subscribed to any streams yet'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: streams.length,
                itemBuilder: (context, index) {
                  final stream = streams[index];
                  return ScheduledStreamCard(
                    stream: stream,
                    streamService: _streamService,
                    isHost: stream.hostId == user.uid,
                    isSubscribed: true,
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