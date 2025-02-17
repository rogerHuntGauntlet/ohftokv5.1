import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:video_compress/video_compress.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SocialMediaService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Formats and shares video to Instagram
  Future<void> shareToInstagram({
    required String videoPath,
    required String caption,
    List<String>? hashtags,
  }) async {
    try {
      // Process video for Instagram
      final processedVideo = await _processVideoForInstagram(videoPath);
      
      // Generate hashtags string
      final hashtagString = hashtags?.map((tag) => '#$tag').join(' ') ?? '';
      final fullCaption = '$caption\n\n$hashtagString';

      // Share to Instagram
      await Share.shareXFiles(
        [XFile(processedVideo.path)],
        text: fullCaption,
      );

      // Track sharing
      await _trackSocialShare('instagram', videoPath);
    } catch (e) {
      print('Error sharing to Instagram: $e');
      rethrow;
    }
  }

  /// Formats and shares video to TikTok
  Future<void> shareToTikTok({
    required String videoPath,
    required String caption,
    List<String>? hashtags,
  }) async {
    try {
      // Process video for TikTok
      final processedVideo = await _processVideoForTikTok(videoPath);
      
      // Generate hashtags string
      final hashtagString = hashtags?.map((tag) => '#$tag').join(' ') ?? '';
      final fullCaption = '$caption\n\n$hashtagString';

      // Share to TikTok
      await Share.shareXFiles(
        [XFile(processedVideo.path)],
        text: fullCaption,
      );

      // Track sharing
      await _trackSocialShare('tiktok', videoPath);
    } catch (e) {
      print('Error sharing to TikTok: $e');
      rethrow;
    }
  }

  /// Formats and shares video to YouTube
  Future<void> shareToYouTube({
    required String videoPath,
    required String title,
    required String description,
    List<String>? hashtags,
  }) async {
    try {
      // Process video for YouTube
      final processedVideo = await _processVideoForYouTube(videoPath);
      
      // Generate hashtags string
      final hashtagString = hashtags?.map((tag) => '#$tag').join(' ') ?? '';
      final fullDescription = '$description\n\n$hashtagString';

      // Share to YouTube
      await Share.shareXFiles(
        [XFile(processedVideo.path)],
        text: '$title\n\n$fullDescription',
      );

      // Track sharing
      await _trackSocialShare('youtube', videoPath);
    } catch (e) {
      print('Error sharing to YouTube: $e');
      rethrow;
    }
  }

  /// Generates hashtag suggestions based on content
  Future<List<String>> generateHashtagSuggestions(String content) async {
    // TODO: Implement AI-based hashtag suggestion
    // For now, return some default hashtags
    return ['ohftok', 'movie', 'creative', 'filmmaking'];
  }

  /// Generates auto-captions for video content
  Future<String> generateCaptions(String videoPath) async {
    // TODO: Implement AI-based caption generation
    return 'Check out my latest creation on OHFtok!';
  }

  // Private helper methods
  Future<File> _processVideoForInstagram(String videoPath) async {
    final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
      videoPath,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
      includeAudio: true,
    );
    
    return File(mediaInfo?.path ?? videoPath);
  }

  Future<File> _processVideoForTikTok(String videoPath) async {
    final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
      videoPath,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
      includeAudio: true,
    );
    
    return File(mediaInfo?.path ?? videoPath);
  }

  Future<File> _processVideoForYouTube(String videoPath) async {
    final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
      videoPath,
      quality: VideoQuality.HighestQuality,
      deleteOrigin: false,
      includeAudio: true,
    );
    
    return File(mediaInfo?.path ?? videoPath);
  }

  Future<void> _trackSocialShare(String platform, String contentId) async {
    await _analytics.logEvent(
      name: 'social_share',
      parameters: {
        'platform': platform,
        'content_id': contentId,
      },
    );

    await _firestore.collection('social_shares').add({
      'platform': platform,
      'contentId': contentId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
} 