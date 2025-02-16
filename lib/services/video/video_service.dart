import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Service responsible for video playback functionality
class VideoService extends ChangeNotifier {
  late final Player _player;
  late VideoController _controller;
  bool _isInitialized = false;
  String? _currentUrl;
  bool _isLooping = true;
  bool _isMuted = false;

  VideoService() {
    _player = Player();
    _initializeController();
  }

  Future<void> _initializeController() async {
    _controller = VideoController(_player);
    notifyListeners();
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isPlaying => _player.state.playing;
  bool get isMuted => _isMuted;
  Duration get position => _player.state.position;
  Duration? get duration => _player.state.duration;
  double get volume => _player.state.volume;
  VideoController get controller => _controller;

  Future<void> initialize(String url) async {
    if (_currentUrl == url) return;
    _currentUrl = url;
    
    await _player.open(Media(url), play: false);
    _isInitialized = true;
    setLooping(_isLooping);
    notifyListeners();
  }

  Future<void> play() async {
    await _player.play();
    notifyListeners();
  }

  Future<void> pause() async {
    await _player.pause();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
    notifyListeners();
  }

  Future<void> setLooping(bool looping) async {
    _isLooping = looping;
    await _player.setPlaylistMode(looping ? PlaylistMode.single : PlaylistMode.none);
    notifyListeners();
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0) * 100);
    notifyListeners();
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await setVolume(_isMuted ? 0.0 : 1.0);
  }

  Widget buildPlayer({BoxFit fit = BoxFit.contain}) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Video(
      controller: _controller,
      fit: fit,
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
} 