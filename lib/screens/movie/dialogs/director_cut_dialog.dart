import 'package:flutter/material.dart';
import '../../../data/famous_directors.dart';
import '../../../services/ai/scene_director_service.dart';
import '../../../models/director.dart';

class DirectorCutDialog extends StatefulWidget {
  final String sceneText;
  final Function(SceneReconception) onDirectorCutSelected;

  const DirectorCutDialog({
    super.key,
    required this.sceneText,
    required this.onDirectorCutSelected,
  });

  @override
  State<DirectorCutDialog> createState() => _DirectorCutDialogState();
}

class _DirectorCutDialogState extends State<DirectorCutDialog> with SingleTickerProviderStateMixin {
  final SceneDirectorService _directorService = SceneDirectorService();
  Director? _selectedDirector;
  bool _isLoading = false;
  String? _error;
  SceneReconception? _directorCut;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _fadeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getDirectorCut() async {
    if (_selectedDirector == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _directorCut = null;
    });

    try {
      final directorCut = await _directorService.reconceiveScene(
        sceneText: widget.sceneText,
        directorName: _selectedDirector!.name,
        directorStyle: _selectedDirector!.style,
      );

      setState(() {
        _directorCut = directorCut;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to get director\'s cut: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black87,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.movie_creation,
                      color: Colors.amber,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Director\'s Cut',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Theme(
                  data: Theme.of(context).copyWith(
                    textTheme: Theme.of(context).textTheme.copyWith(
                      bodyMedium: const TextStyle(fontSize: 14),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: DropdownButtonFormField<Director>(
                      value: _selectedDirector,
                      isExpanded: true,
                      dropdownColor: Colors.black87,
                      decoration: const InputDecoration(
                        labelText: 'Choose Your Director',
                        labelStyle: TextStyle(color: Colors.amber),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      style: const TextStyle(color: Colors.white),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.amber),
                      selectedItemBuilder: (context) => famousDirectors.map((director) {
                        return Text(
                          director.name,
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        );
                      }).toList(),
                      items: famousDirectors.map((director) {
                        return DropdownMenuItem(
                          value: director,
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 80),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  director.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.amber,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Flexible(
                                  child: Text(
                                    director.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[400],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (director) {
                        setState(() {
                          _selectedDirector = director;
                          _directorCut = null;
                        });
                        _getDirectorCut();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  Center(
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _fadeAnimation,
                          builder: (context, child) {
                            return Column(
                              children: [
                                Icon(
                                  Icons.movie_filter,
                                  color: Colors.amber.withOpacity(_fadeAnimation.value),
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Reimagining Scene...',
                                  style: TextStyle(
                                    color: Colors.amber.withOpacity(_fadeAnimation.value),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Through ${_selectedDirector?.name}\'s Lens',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(_fadeAnimation.value),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        const LinearProgressIndicator(
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                        ),
                      ],
                    ),
                )
                else if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else if (_directorCut != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.withOpacity(0.1),
                          Colors.blue.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.movie_filter, color: Colors.amber, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Through ${_directorCut!.directorName}\'s Lens',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Reimagined Scene',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _directorCut!.sceneDescription,
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Director\'s Vision',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _directorCut!.directorNotes,
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontStyle: FontStyle.italic,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white60,
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          widget.onDirectorCutSelected(_directorCut!);
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('Use This Version'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
} 