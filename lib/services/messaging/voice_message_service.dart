import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class VoiceMessageService {
  late final AudioRecorder _recorder;
  final _player = AudioPlayer();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  String? _recordingPath;
  final _uuid = const Uuid();
  bool _isInitialized = false;
  final _stateController = StreamController<PlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();

  VoiceMessageService() {
    _recorder = AudioRecorder();
    _setupPlayerListeners();
  }

  void _setupPlayerListeners() {
    _player.onPlayerStateChanged.listen((state) {
      _stateController.add(state);
    });

    _player.onPositionChanged.listen((position) {
      _positionController.add(position);
    });

    _player.onDurationChanged.listen((duration) {
      _durationController.add(duration);
    });
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission not granted');
    }

    _isInitialized = true;
  }

  Future<void> startRecording() async {
    if (!_isInitialized) {
      await initialize();
    }

    final directory = await getTemporaryDirectory();
    _recordingPath = '${directory.path}/${_uuid.v4()}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
      ),
      path: _recordingPath!,
    );
  }

  Future<String?> stopRecording() async {
    if (!_isInitialized || _recordingPath == null) return null;

    final path = await _recorder.stop();
    return path;
  }

  Future<String?> uploadVoiceMessage(String filePath, String conversationId) async {
    try {
      final file = File(filePath);
      final fileName = '${_uuid.v4()}.m4a';
      final ref = _storage.ref('voice_messages/$conversationId/$fileName');
      
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      
      // Delete the temporary file
      await file.delete();
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading voice message: $e');
      return null;
    }
  }

  Future<void> playVoiceMessage(String url) async {
    try {
      await _player.play(UrlSource(url));
    } catch (e) {
      print('Error playing voice message: $e');
    }
  }

  Future<void> stopPlaying() async {
    await _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _recorder.dispose();
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
    _isInitialized = false;
  }

  Future<bool> get isRecording => _recorder.isRecording();
  bool get isPlaying => _player.state == PlayerState.playing;

  Stream<PlayerState> get playbackStateStream => _stateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
} 