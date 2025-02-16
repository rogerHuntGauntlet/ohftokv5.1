import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/social/auth_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final Set<String> _selectedInterests = <String>{};

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const OnboardingPage(
        title: 'Welcome to OHFtok!',
        description: 'Join our creative community and share your amazing moments.',
        icon: Icons.celebration,
      ),
      const OnboardingPage(
        title: 'Create & Share',
        description: 'Upload videos, add effects, and share your creativity with the world.',
        icon: Icons.video_camera_back,
      ),
      const OnboardingPage(
        title: 'Connect & Engage',
        description: 'Follow creators, engage with content, and build your audience.',
        icon: Icons.people,
      ),
      const OnboardingPage(
        title: 'Earn Rewards',
        description: 'Get tokens for your engagement and unlock exclusive features.',
        icon: Icons.stars,
      ),
      InterestsPage(
        selectedInterests: _selectedInterests,
        onInterestsChanged: (interests) {
          setState(() {
            _selectedInterests.clear();
            _selectedInterests.addAll(interests);
          });
        },
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      if (_selectedInterests.length >= 3) {
        _completeOnboarding();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least 3 interests'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _completeOnboarding() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      // Mark onboarding as completed and save interests in Firestore
      await authService.updateProfile(
        uid: authService.currentUser!.uid,
        hasCompletedOnboarding: true,
        interests: _selectedInterests.toList(),
      );
      
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing setup: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _handleSkip() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final defaultInterests = ['Music', 'Entertainment', 'Trending'];
    try {
      // Attempt to update the user's profile with default interests
      await authService.updateProfile(
        uid: authService.currentUser!.uid,
        hasCompletedOnboarding: true,
        interests: defaultInterests,
      );
    } catch (e) {
      // Any error is ignored; do not show an error message.
    } finally {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: _pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page indicators
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ),
                  // Next/Complete button
                  ElevatedButton(
                    onPressed: _onNextPage,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                    ),
                  ),
                ],
              ),
            ),
            // Skip button
            if (_currentPage < _pages.length - 1)
              TextButton(
                onPressed: _handleSkip,
                child: const Text('Skip'),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const OnboardingPage({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 100,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class InterestsPage extends StatefulWidget {
  final Set<String> selectedInterests;
  final Function(Set<String>) onInterestsChanged;

  const InterestsPage({
    super.key,
    required this.selectedInterests,
    required this.onInterestsChanged,
  });

  @override
  State<InterestsPage> createState() => _InterestsPageState();
}

class _InterestsPageState extends State<InterestsPage> {
  static const List<String> _availableInterests = [
    'Music', 'Dance', 'Comedy', 'Food',
    'Fashion', 'Beauty', 'Sports', 'Gaming',
    'Education', 'Technology', 'Travel', 'Art',
    'Fitness', 'Lifestyle', 'Pets', 'Nature',
  ];

  late Set<String> _localSelectedInterests;

  @override
  void initState() {
    super.initState();
    _localSelectedInterests = Set<String>.from(widget.selectedInterests);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'What interests you?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Selected ${_localSelectedInterests.length} of 3 required topics',
            style: TextStyle(
              fontSize: 16,
              color: _localSelectedInterests.length >= 3 ? Colors.green : Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _availableInterests.length,
              itemBuilder: (context, index) {
                final interest = _availableInterests[index];
                final isSelected = _localSelectedInterests.contains(interest);
                
                return FilterChip(
                  label: Text(interest),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _localSelectedInterests.add(interest);
                      } else {
                        _localSelectedInterests.remove(interest);
                      }
                      widget.onInterestsChanged(_localSelectedInterests);
                    });
                  },
                  selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                  checkmarkColor: Theme.of(context).primaryColor,
                  showCheckmark: true,
                  avatar: isSelected ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).primaryColor,
                    size: 18,
                  ) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 