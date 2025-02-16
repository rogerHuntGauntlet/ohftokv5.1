import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import '../../services/movie/movie_service.dart';

class SceneEditScreen extends StatefulWidget {
  final Map<String, dynamic> scene;
  final String movieIdea;

  const SceneEditScreen({
    super.key,
    required this.scene,
    required this.movieIdea,
  });

  @override
  State<SceneEditScreen> createState() => _SceneEditScreenState();
}

class _SceneEditScreenState extends State<SceneEditScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _currentNote = '';
  bool _isProcessing = false;
  bool _isSpeechInitialized = false;
  List<Map<String, dynamic>> _sceneHistory = [];

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _loadSceneHistory();
  }

  void _loadSceneHistory() {
    setState(() {
      _sceneHistory = [
        {
          'text': widget.scene['text'],
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'original'
        },
        ...(widget.scene['notes'] ?? []).map<Map<String, dynamic>>((note) => {
          'text': note['text'],
          'timestamp': note['timestamp'],
          'type': 'note'
        }).toList(),
      ];
    });
  }

  Future<void> _initializeSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done') {
            setState(() => _isListening = false);
            if (_currentNote.isNotEmpty) {
              _processNote();
            }
          }
        },
        onError: (error) {
          print('Speech Error: $error');
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
          );
        },
      );
      setState(() => _isSpeechInitialized = available);
    } catch (e) {
      print('Speech initialization error: $e');
      setState(() => _isSpeechInitialized = false);
    }
  }

  Future<void> _startListening() async {
    if (!_isSpeechInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition is not initialized')),
      );
      return;
    }

    setState(() {
      _currentNote = '';
      _isListening = true;
    });

    try {
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _currentNote = result.recognizedWords;
          });
        },
      );
    } catch (e) {
      print('Listen error: $e');
      setState(() {
        _isListening = false;
        _currentNote = '';
      });
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
    if (_currentNote.isNotEmpty) {
      _processNote();
    }
  }

  Future<void> _processNote() async {
    if (_currentNote.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final movieService = Provider.of<MovieService>(context, listen: false);
      final updatedScene = await movieService.updateSceneWithNote(
        widget.scene,
        _currentNote,
        widget.movieIdea,
      );

      setState(() {
        _sceneHistory.add({
          'text': _currentNote,
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'note'
        });
        if (updatedScene != null) {
          _sceneHistory.add({
            'text': updatedScene['text'],
            'timestamp': DateTime.now().toIso8601String(),
            'type': 'update'
          });
        }
        _currentNote = '';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing note: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _deleteHistoryItem(int index) {
    setState(() {
      _sceneHistory.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Scene'),
        actions: [
          if (_isListening)
            IconButton(
              onPressed: _stopListening,
              icon: const Icon(Icons.stop),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _sceneHistory.length,
                itemBuilder: (context, index) {
                  final item = _sceneHistory[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(
                        _getIconForType(item['type']),
                        color: _getColorForType(item['type']),
                      ),
                      title: Text(item['text']),
                      subtitle: Text(
                        _formatTimestamp(item['timestamp']),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: item['type'] == 'note' ? IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteHistoryItem(index),
                      ) : null,
                    ),
                  );
                },
              ),
            ),
            if (_isListening || _currentNote.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[200],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isListening ? 'Listening...' : 'Review your note:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_currentNote.isEmpty ? '...' : _currentNote),
                    if (!_isListening && _currentNote.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _currentNote = ''),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: _processNote,
                            child: const Text('Add Note'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: !_isListening && _currentNote.isEmpty ? FloatingActionButton(
        onPressed: _isProcessing ? null : _startListening,
        child: Icon(_isProcessing ? Icons.hourglass_empty : Icons.mic),
      ) : null,
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'original':
        return Icons.movie;
      case 'note':
        return Icons.note;
      case 'update':
        return Icons.update;
      default:
        return Icons.text_fields;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'original':
        return Colors.blue;
      case 'note':
        return Colors.green;
      case 'update':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(String timestamp) {
    final date = DateTime.parse(timestamp);
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')} ${date.day}/${date.month}/${date.year}';
  }
} 