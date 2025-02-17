import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

class StreamSharingService {
  final FirebaseDynamicLinks _dynamicLinks = FirebaseDynamicLinks.instance;
  
  /// Generates a unique, shareable URL for a stream
  Future<String> generateStreamLink({
    required String streamId,
    required String streamTitle,
    String? description,
    String? thumbnailUrl,
    bool isExpirable = false,
    Duration? expiryDuration,
  }) async {
    final DynamicLinkParameters parameters = DynamicLinkParameters(
      uriPrefix: 'https://ohftok.page.link',
      link: Uri.parse('https://ohftok.com/stream/$streamId'),
      androidParameters: const AndroidParameters(
        packageName: 'com.ohftok.app',
        minimumVersion: 0,
      ),
      iosParameters: const IOSParameters(
        bundleId: 'com.ohftok.app',
        minimumVersion: '0',
      ),
      socialMetaTagParameters: SocialMetaTagParameters(
        title: streamTitle,
        description: description ?? 'Join this live stream on OHFtok!',
        imageUrl: thumbnailUrl != null ? Uri.parse(thumbnailUrl) : null,
      ),
    );

    final shortLink = await _dynamicLinks.buildShortLink(parameters);
    return shortLink.shortUrl.toString();
  }

  /// Generates a QR code for a stream
  Widget generateQRCode(String streamUrl) {
    return QrImageView(
      data: streamUrl,
      version: QrVersions.auto,
      size: 200.0,
      backgroundColor: Colors.white,
    );
  }

  /// Shares a stream link using the platform's share sheet
  Future<void> shareStream({
    required String streamUrl,
    required String streamTitle,
    String? message,
  }) async {
    final String shareMessage = message ?? 'Join my live stream: $streamTitle';
    await Share.share('$shareMessage\n$streamUrl');
  }

  /// Tracks link clicks and engagement
  Future<void> trackLinkEngagement(String streamId, String linkId) async {
    // TODO: Implement analytics tracking
    // This will be implemented when we add analytics service
  }
} 