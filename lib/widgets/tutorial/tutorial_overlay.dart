import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialOverlay extends StatefulWidget {
  final Widget child;
  final String featureKey;
  final String title;
  final String description;
  final Offset targetPosition;
  final Size targetSize;

  const TutorialOverlay({
    super.key,
    required this.child,
    required this.featureKey,
    required this.title,
    required this.description,
    required this.targetPosition,
    required this.targetSize,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> with SingleTickerProviderStateMixin {
  bool _showOverlay = false;
  late AnimationController _controller;
  late Animation<double> _animation;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _checkIfShouldShow();
  }

  Future<void> _checkIfShouldShow() async {
    _prefs = await SharedPreferences.getInstance();
    final hasShown = _prefs?.getBool('tutorial_${widget.featureKey}') ?? false;
    if (!hasShown) {
      setState(() => _showOverlay = true);
      _controller.forward();
    }
  }

  void _hideOverlay() async {
    await _controller.reverse();
    setState(() => _showOverlay = false);
    await _prefs?.setBool('tutorial_${widget.featureKey}', true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showOverlay) return widget.child;

    // Get screen size
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        widget.child,
        FadeTransition(
          opacity: _animation,
          child: GestureDetector(
            onTap: _hideOverlay,
            child: Container(
              width: screenSize.width,
              height: screenSize.height,
              color: Colors.black54,
              child: Stack(
                children: [
                  // Highlight target area
                  if (widget.targetPosition != Offset.zero && widget.targetSize != Size.zero)
                    Positioned(
                      left: widget.targetPosition.dx,
                      top: widget.targetPosition.dy,
                      child: Container(
                        width: widget.targetSize.width,
                        height: widget.targetSize.height,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  // Tutorial content
                  Positioned(
                    left: widget.targetPosition.dx.clamp(16, screenSize.width - 266),
                    top: (widget.targetPosition.dy + widget.targetSize.height + 16)
                        .clamp(16, screenSize.height - 200),
                    child: Container(
                      width: 250,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.description,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _hideOverlay,
                              child: const Text('Got it'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
} 