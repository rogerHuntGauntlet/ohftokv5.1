import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class BaseSharingService {
  final FirebaseDynamicLinks _dynamicLinks = FirebaseDynamicLinks.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Generates a unique, shareable URL
  Future<String> generateDynamicLink({
    required String path,
    required String title,
    String? description,
    String? thumbnailUrl,
    bool isExpirable = false,
    Duration? expiryDuration,
  }) async {
    final DynamicLinkParameters parameters = DynamicLinkParameters(
      uriPrefix: 'https://ohftok.page.link',
      link: Uri.parse('https://ohftok.com$path'),
      androidParameters: const AndroidParameters(
        packageName: 'com.ohftok.app',
        minimumVersion: 0,
      ),
      iosParameters: const IOSParameters(
        bundleId: 'com.ohftok.app',
        minimumVersion: '0',
      ),
      socialMetaTagParameters: SocialMetaTagParameters(
        title: title,
        description: description ?? 'Check this out on OHFtok!',
        imageUrl: thumbnailUrl != null ? Uri.parse(thumbnailUrl) : null,
      ),
    );

    final shortLink = await _dynamicLinks.buildShortLink(parameters);
    final linkId = _generateLinkId();
    
    // Store link data for analytics
    await _storeLinkData(linkId, {
      'path': path,
      'title': title,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'isExpirable': isExpirable,
      'expiryDate': isExpirable && expiryDuration != null 
          ? DateTime.now().add(expiryDuration).toIso8601String()
          : null,
      'createdAt': DateTime.now().toIso8601String(),
      'clicks': 0,
    });

    return shortLink.shortUrl.toString();
  }

  /// Generates a QR code for a URL
  Widget generateQRCode(String url) {
    return QrImageView(
      data: url,
      version: QrVersions.auto,
      size: 200.0,
      backgroundColor: Colors.white,
    );
  }

  /// Shares content using the platform's share sheet
  Future<void> shareContent({
    required String url,
    required String title,
    String? message,
  }) async {
    final String shareMessage = message ?? 'Check this out: $title';
    await Share.share('$shareMessage\n$url');
  }

  /// Tracks link clicks and engagement
  Future<void> trackLinkClick(String linkId) async {
    await _firestore.collection('links').doc(linkId).update({
      'clicks': FieldValue.increment(1),
      'lastClickedAt': DateTime.now().toIso8601String(),
    });

    await _analytics.logEvent(
      name: 'link_click',
      parameters: {
        'link_id': linkId,
      },
    );
  }

  /// Gets link statistics
  Future<Map<String, dynamic>> getLinkStats(String linkId) async {
    final doc = await _firestore.collection('links').doc(linkId).get();
    return doc.data() ?? {};
  }

  /// Copies URL to clipboard
  Future<void> copyToClipboard(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
  }

  // Private helper methods
  String _generateLinkId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().toString()}';
  }

  Future<void> _storeLinkData(String linkId, Map<String, dynamic> data) async {
    await _firestore.collection('links').doc(linkId).set(data);
  }
} 