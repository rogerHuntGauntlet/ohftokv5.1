import 'dart:io';
import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class VideoMessageService {
  static final VideoMessageService _instance = VideoMessageService._internal();
  factory VideoMessageService() => _instance;
  VideoMessageService._internal();

  CameraController? _cameraController;
  bool _isRecording = false;
  final _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No cameras available');
    
    final camera = cameras.first;
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: true,
    );

    await _cameraController?.initialize();
  }

  Future<void> disposeCamera() async {
    await _cameraController?.dispose();
    _cameraController = null;
  }

  Future<String> startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }

    if (_isRecording) throw Exception('Already recording');

    try {
      await _cameraController!.startVideoRecording();
      _isRecording = true;
      return 'Recording started';
    } catch (e) {
      throw Exception('Failed to start recording: $e');
    }
  }

  Future<String> stopRecording() async {
    if (_cameraController == null || !_isRecording) {
      throw Exception('Not recording');
    }

    try {
      final videoFile = await _cameraController!.stopVideoRecording();
      _isRecording = false;
      
      // Compress the video
      final compressedPath = await _compressVideo(videoFile.path);
      
      // Upload to Firebase Storage
      final downloadUrl = await _uploadVideo(compressedPath);
      
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to stop recording: $e');
    }
  }

  Future<String> _compressVideo(String inputPath) async {
    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/${_uuid.v4()}.mp4';

    // Compress video using FFmpeg
    // -vf scale=720:-2 resizes to 720p maintaining aspect ratio
    // -c:v libx264 uses h264 codec
    // -crf 28 sets compression quality (23-28 is good for messaging)
    // -preset faster optimizes for speed vs compression
    await FFmpegKit.execute(
      '-i $inputPath -vf scale=720:-2 -c:v libx264 -crf 28 -preset faster -c:a aac $outputPath'
    );

    return outputPath;
  }

  Future<String> _uploadVideo(String videoPath) async {
    final fileName = '${_uuid.v4()}.mp4';
    final ref = _storage.ref().child('video_messages/$fileName');
    
    final uploadTask = ref.putFile(File(videoPath));
    final snapshot = await uploadTask;
    
    return await snapshot.ref.getDownloadURL();
  }

  bool get isRecording => _isRecording;
  CameraController? get cameraController => _cameraController;
} 