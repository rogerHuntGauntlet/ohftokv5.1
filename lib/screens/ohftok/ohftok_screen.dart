import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../movie/movie_scenes_screen.dart';
import '../training/director_training_screen.dart';
import '../home/home_page.dart';
import '../feed/feed_screen.dart';

class OhftokScreen extends StatefulWidget {
  const OhftokScreen({Key? key}) : super(key: key);

  static const String routeName = '/ohftok';

  @override
  State<OhftokScreen> createState() => _OhftokScreenState();
}

class _OhftokScreenState extends State<OhftokScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final List<NavigationItem> _items;

  @override
  void initState() {
    super.initState();
    _items = [
      NavigationItem(
        title: 'Feed',
        icon: Icons.auto_awesome,
        gradient: const LinearGradient(
          colors: [Color(0xFF9C27B0), Color(0xFF2196F3)],
        ),
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FeedScreen(),
            ),
          );
        },
      ),
      NavigationItem(
        title: 'Create',
        icon: Icons.add_circle_outline,
        gradient: const LinearGradient(
          colors: [Color(0xFFFF4081), Color(0xFFFFA000)],
        ),
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HomePage(),
            ),
          );
        },
      ),
      NavigationItem(
        title: 'Profile',
        icon: Icons.person_outline,
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF009688)],
        ),
        onTap: (context) {
          Navigator.pushNamed(context, '/profile');
        },
      ),
      NavigationItem(
        title: 'Learn',
        icon: Icons.school_outlined,
        gradient: const LinearGradient(
          colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
        ),
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DirectorTrainingScreen(),
            ),
          );
        },
      ),
    ];
  }

  void _navigateToMovie(String movieId, Map<String, dynamic> movieData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieScenesScreen(
          movieIdea: movieData['idea'] ?? '',
          scenes: List<Map<String, dynamic>>.from(movieData['scenes'] ?? []),
          movieId: movieId,
          movieTitle: movieData['title'] ?? 'Untitled',
          isReadOnly: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'OHFtok',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
            ),
            // Navigation Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                return _buildNavigationCard(_items[index]);
              },
            ),
            const SizedBox(height: 24),
            // Public Movies List
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Public Movies',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Movies List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('movies')
                    .where('isPublic', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Something went wrong',
                          style: TextStyle(color: Colors.white)),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final movies = snapshot.data?.docs ?? [];

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: movies.length,
                    itemBuilder: (context, index) {
                      return _buildMovieCard(movies[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationCard(NavigationItem item) {
    return GestureDetector(
      onTap: () => item.onTap(context),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: item.gradient,
          boxShadow: [
            BoxShadow(
              color: item.gradient.colors.first.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 40,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMovieCard(DocumentSnapshot doc) {
    final movieData = doc.data() as Map<String, dynamic>;
    final String movieId = doc.id;
    
    return GestureDetector(
      onTap: () => _navigateToMovie(movieId, movieData),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.1),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.movie, color: Colors.white54),
          ),
          title: Text(
            movieData['title'] ?? 'Untitled',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            movieData['creator'] ?? 'Unknown Creator',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class NavigationItem {
  final String title;
  final IconData icon;
  final LinearGradient gradient;
  final Function(BuildContext) onTap;

  NavigationItem({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });
}

class PsychedelicBackgroundPainter extends CustomPainter {
  final double animation;

  PsychedelicBackgroundPainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 1; i <= 5; i++) {
      final progress = (animation + (i / 5)) % 1.0;
      final center = Offset(
        size.width * 0.5 + size.width * 0.3 * cos(progress * 2 * 3.14),
        size.height * 0.5 + size.height * 0.3 * sin(progress * 2 * 3.14),
      );

      final gradient = RadialGradient(
        colors: [
          HSLColor.fromAHSL(0.3, (360 * progress) % 360, 0.8, 0.5).toColor(),
          HSLColor.fromAHSL(0.0, (360 * progress + 60) % 360, 0.8, 0.5).toColor(),
        ],
      );

      paint.shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: size.width * 0.8),
      );

      canvas.drawCircle(center, size.width * 0.8, paint);
    }
  }

  @override
  bool shouldRepaint(PsychedelicBackgroundPainter oldDelegate) =>
      animation != oldDelegate.animation;
} 