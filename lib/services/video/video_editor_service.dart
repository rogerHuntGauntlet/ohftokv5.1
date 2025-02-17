import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';

class VideoEditorService {
  /// Trims a video file to the specified start and end times
  Future<File?> trimVideo({
    required File videoFile,
    required Duration startTime,
    required Duration endTime,
  }) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String outputPath = '${tempDir.path}/trimmed_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final String command = '-i "${videoFile.path}" -ss ${startTime.inSeconds} -t ${endTime.difference(startTime).inSeconds} -c copy "$outputPath"';
      
      final session = await FFmpegKit.execute(command);
      final ReturnCode? returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return File(outputPath);
      } else {
        throw Exception('Failed to trim video');
      }
    } catch (e) {
      debugPrint('Error trimming video: $e');
      return null;
    }
  }

  /// Splits a video into two parts at the specified timestamp
  Future<List<File>?> splitVideo({
    required File videoFile,
    required Duration splitPoint,
  }) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String part1Path = '${tempDir.path}/part1_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final String part2Path = '${tempDir.path}/part2_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Create first part
      final String command1 = '-i "${videoFile.path}" -t ${splitPoint.inSeconds} -c copy "$part1Path"';
      final session1 = await FFmpegKit.execute(command1);
      final returnCode1 = await session1.getReturnCode();

      // Create second part
      final String command2 = '-i "${videoFile.path}" -ss ${splitPoint.inSeconds} -c copy "$part2Path"';
      final session2 = await FFmpegKit.execute(command2);
      final returnCode2 = await session2.getReturnCode();

      if (ReturnCode.isSuccess(returnCode1) && ReturnCode.isSuccess(returnCode2)) {
        return [File(part1Path), File(part2Path)];
      } else {
        throw Exception('Failed to split video');
      }
    } catch (e) {
      debugPrint('Error splitting video: $e');
      return null;
    }
  }

  /// Merges multiple video clips into a single video
  Future<File?> mergeClips({
    required List<File> videoFiles,
    String? transitionEffect,
  }) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String outputPath = '${tempDir.path}/merged_${DateTime.now().millisecondsSinceEpoch}.mp4';
      
      // Create a temporary file listing all input videos
      final File inputList = File('${tempDir.path}/input_list.txt');
      String fileContent = '';
      for (var file in videoFiles) {
        fileContent += "file '${file.path}'\n";
      }
      await inputList.writeAsString(fileContent);

      String command;
      if (transitionEffect != null) {
        // Add transition effect between clips
        command = '-f concat -safe 0 -i "${inputList.path}" -filter_complex "[0:v]xfade=transition=$transitionEffect:duration=1[v]" -map "[v]" "$outputPath"';
      } else {
        // Simple concatenation without transitions
        command = '-f concat -safe 0 -i "${inputList.path}" -c copy "$outputPath"';
      }

      final session = await FFmpegKit.execute(command);
      final ReturnCode? returnCode = await session.getReturnCode();

      // Clean up input list file
      await inputList.delete();

      if (ReturnCode.isSuccess(returnCode)) {
        return File(outputPath);
      } else {
        throw Exception('Failed to merge video clips');
      }
    } catch (e) {
      debugPrint('Error merging video clips: $e');
      return null;
    }
  }

  /// Adds a transition effect between two videos
  Future<File?> addTransition({
    required File video1,
    required File video2,
    required String transitionEffect,
    Duration transitionDuration = const Duration(seconds: 1),
  }) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String outputPath = '${tempDir.path}/transition_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final String command = '''
        -i "${video1.path}" -i "${video2.path}" 
        -filter_complex "
        [0:v][1:v]xfade=transition=$transitionEffect:duration=${transitionDuration.inSeconds}:offset=${await _getVideoDuration(video1) - transitionDuration.inSeconds}[v]
        " -map "[v]" "$outputPath"
      ''';

      final session = await FFmpegKit.execute(command);
      final ReturnCode? returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return File(outputPath);
      } else {
        throw Exception('Failed to add transition');
      }
    } catch (e) {
      debugPrint('Error adding transition: $e');
      return null;
    }
  }

  /// Gets the duration of a video file
  Future<double> _getVideoDuration(File videoFile) async {
    final controller = VideoPlayerController.file(videoFile);
    await controller.initialize();
    final duration = controller.value.duration.inSeconds.toDouble();
    await controller.dispose();
    return duration;
  }

  /// Applies a video filter using FFmpeg
  Future<File?> applyFilter({
    required File videoFile,
    required String filterType,
    double intensity = 1.0,
  }) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String outputPath = '${tempDir.path}/filtered_${DateTime.now().millisecondsSinceEpoch}.mp4';

      String filterCommand;
      switch (filterType) {
        case 'brightness':
          filterCommand = 'eq=brightness=${intensity.toStringAsFixed(2)}';
        case 'contrast':
          filterCommand = 'eq=contrast=${intensity.toStringAsFixed(2)}';
        case 'saturation':
          filterCommand = 'eq=saturation=${intensity.toStringAsFixed(2)}';
        case 'sepia':
          filterCommand = 'colorize=rs=.393:gs=.769:bs=.189:rm=.349:gm=.686:bm=.168:rh=.272:gh=.534:bh=.131';
        case 'grayscale':
          filterCommand = 'colorchannelmixer=.3:.59:.11:0:.3:.59:.11:0:.3:.59:.11';
        default:
          throw Exception('Unsupported filter type: $filterType');
      }

      final String command = '-i "${videoFile.path}" -vf "$filterCommand" -c:a copy "$outputPath"';
      
      final session = await FFmpegKit.execute(command);
      final ReturnCode? returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return File(outputPath);
      } else {
        throw Exception('Failed to apply filter');
      }
    } catch (e) {
      debugPrint('Error applying filter: $e');
      return null;
    }
  }

  /// Adds text overlay to video
  Future<File?> addTextOverlay({
    required File videoFile,
    required String text,
    required Map<String, dynamic> textStyle,
    required Offset position,
  }) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String outputPath = '${tempDir.path}/text_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Convert position to FFmpeg coordinates
      final String x = position.dx.toStringAsFixed(0);
      final String y = position.dy.toStringAsFixed(0);

      // Build text style
      final String fontFile = textStyle['fontFile'] ?? '/system/fonts/Roboto-Regular.ttf';
      final String fontSize = (textStyle['fontSize'] ?? 24).toString();
      final String fontColor = textStyle['color'] ?? 'white';
      final String shadowColor = textStyle['shadowColor'] ?? 'black@0.5';
      final String shadowX = (textStyle['shadowOffset']?.dx ?? 2).toString();
      final String shadowY = (textStyle['shadowOffset']?.dy ?? 2).toString();

      final String command = '''
        -i "${videoFile.path}" -vf "drawtext=text='$text':
        fontfile='$fontFile':fontsize=$fontSize:fontcolor=$fontColor:
        x=$x:y=$y:shadowcolor=$shadowColor:shadowx=$shadowX:shadowy=$shadowY"
        -c:a copy "$outputPath"
      ''';
      
      final session = await FFmpegKit.execute(command);
      final ReturnCode? returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return File(outputPath);
      } else {
        throw Exception('Failed to add text overlay');
      }
    } catch (e) {
      debugPrint('Error adding text overlay: $e');
      return null;
    }
  }

  /// Adjusts video speed
  Future<File?> adjustSpeed({
    required File videoFile,
    required double speedFactor,
  }) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String outputPath = '${tempDir.path}/speed_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // setpts for video speed, atempo for audio speed (between 0.5 and 2.0)
      final String command = '''
        -i "${videoFile.path}" -filter_complex "[0:v]setpts=${1/speedFactor}*PTS[v];
        [0:a]atempo=$speedFactor[a]" -map "[v]" -map "[a]" "$outputPath"
      ''';
      
      final session = await FFmpegKit.execute(command);
      final ReturnCode? returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return File(outputPath);
      } else {
        throw Exception('Failed to adjust video speed');
      }
    } catch (e) {
      debugPrint('Error adjusting video speed: $e');
      return null;
    }
  }

  /// Adds background music to video
  Future<File?> addBackgroundMusic({
    required File videoFile,
    required File audioFile,
    double musicVolume = 0.5,
    double originalVolume = 1.0,
  }) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String outputPath = '${tempDir.path}/music_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final String command = '''
        -i "${videoFile.path}" -i "${audioFile.path}" -filter_complex "
        [0:a]volume=$originalVolume[a1];
        [1:a]volume=$musicVolume[a2];
        [a1][a2]amix=inputs=2:duration=first[a]
        " -map 0:v -map "[a]" "$outputPath"
      ''';
      
      final session = await FFmpegKit.execute(command);
      final ReturnCode? returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return File(outputPath);
      } else {
        throw Exception('Failed to add background music');
      }
    } catch (e) {
      debugPrint('Error adding background music: $e');
      return null;
    }
  }
} 