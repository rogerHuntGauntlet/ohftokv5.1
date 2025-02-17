import 'package:flutter/material.dart';
import '../../models/feed_item.dart';
import '../../services/feed/feed_service.dart';
import '../../widgets/feed/feed_item_widget.dart';
import 'create_post_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  final FeedService _feedService = FeedService();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  
  List<FeedItem> _feedItems = [];
  String? _lastItemId;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadFeed();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final items = _tabController.index == 0
          ? await _feedService.getFollowingFeed(lastItemId: _lastItemId)
          : await _feedService.getFeedItems(lastItemId: _lastItemId);

      setState(() {
        if (items.isEmpty) {
          _hasMore = false;
        } else {
          _feedItems.addAll(items);
          _lastItemId = items.last.id;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading feed: ${e.toString()}')),
      );
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadFeed();
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _feedItems.clear();
      _lastItemId = null;
      _hasMore = true;
    });
    await _loadFeed();
  }

  Future<void> _showCreatePost() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Expanded(
                child: CreatePostScreen(),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true) {
      // Post was created successfully, refresh the feed
      _onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            setState(() {
              _feedItems.clear();
              _lastItemId = null;
              _hasMore = true;
            });
            _loadFeed();
          },
          tabs: const [
            Tab(text: 'Following'),
            Tab(text: 'For You'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _feedItems.isEmpty && !_isLoading
          ? const Center(
              child: Text('No feed items to display'),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount: _feedItems.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _feedItems.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                return FeedItemWidget(
                  feedItem: _feedItems[index],
                  onLikePressed: () async {
                    try {
                      await _feedService.toggleLike(_feedItems[index].id);
                      // Refresh the feed item to update like status
                      final items = await _feedService.getFeedItems(
                        lastItemId: _feedItems[index].id,
                        userId: _feedItems[index].userId,
                      );
                      if (items.isNotEmpty) {
                        setState(() {
                          _feedItems[index] = items.first;
                        });
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  },
                );
              },
            ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePost,
        child: const Icon(Icons.add),
        tooltip: 'Create Post',
      ),
    );
  }
} 