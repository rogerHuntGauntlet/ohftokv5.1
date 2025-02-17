import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'base_sharing_service.dart';

class StreamSharingService extends BaseSharingService {
  final FirebaseDynamicLinks _dynamicLinks = FirebaseDynamicLinks.instance;
  
  /// Generates a unique, shareable URL for a stream
  @override
  Future<String> generateDynamicLink({
    required String path,
    required String title,
    String? description,
    String? thumbnailUrl,
    bool isExpirable = true,
    Duration? expiryDuration,
    String? streamId,
  }) async {
    return super.generateDynamicLink(
      path: streamId != null ? '/stream/$streamId' : path,
      title: title,
      description: description ?? 'Join this live stream on OHFtok!',
      thumbnailUrl: thumbnailUrl,
      isExpirable: isExpirable,
      expiryDuration: expiryDuration ?? const Duration(hours: 24),
    );
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
    await shareContent(
      url: streamUrl,
      title: streamTitle,
      message: message,
    );
  }

  /// Tracks link clicks and engagement
  Future<void> trackLinkEngagement(String streamId, String linkId) async {
    // TODO: Implement analytics tracking
    // This will be implemented when we add analytics service
  }
} 