import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../models/message.dart';

class MessageAttachmentService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Upload a file and return a FileAttachment object
  Future<FileAttachment> uploadFile(File file, String conversationId) async {
    final String fileName = path.basename(file.path);
    final String fileExtension = path.extension(file.path).toLowerCase();
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String storagePath = 'conversations/$conversationId/files/$timestamp\_$fileName';
    
    // Get file size
    final int fileSize = await file.length();
    
    // Upload file
    final TaskSnapshot uploadTask = await _storage.ref(storagePath).putFile(file);
    final String downloadUrl = await uploadTask.ref.getDownloadURL();
    
    // Generate thumbnail for images and videos if needed
    String? thumbnailUrl;
    if (fileExtension.contains(RegExp(r'\.(jpg|jpeg|png|gif|mp4|mov)$'))) {
      thumbnailUrl = await _generateThumbnail(file, conversationId, timestamp);
    }
    
    return FileAttachment(
      url: downloadUrl,
      fileName: fileName,
      fileType: fileExtension,
      fileSize: fileSize,
      thumbnailUrl: thumbnailUrl,
    );
  }
  
  // Generate thumbnail for images and videos
  Future<String?> _generateThumbnail(File file, String conversationId, String timestamp) async {
    // Implementation would depend on the image/video processing library you're using
    // For now, returning null as placeholder
    return null;
  }
  
  // Get current location with address information
  Future<LocationInfo> getCurrentLocation() async {
    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }
    
    // Get current position
    final Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    
    // Get address from coordinates
    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    
    if (placemarks.isNotEmpty) {
      Placemark place = placemarks.first;
      String address = '${place.street}, ${place.locality}, ${place.country}';
      String placeName = place.name ?? 'Unknown location';
      
      return LocationInfo(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        placeName: placeName,
        additionalInfo: {
          'accuracy': position.accuracy,
          'altitude': position.altitude,
          'speed': position.speed,
          'timestamp': position.timestamp?.toIso8601String(),
        },
      );
    } else {
      return LocationInfo(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }
  }
  
  // Delete a file attachment
  Future<void> deleteFileAttachment(FileAttachment attachment) async {
    try {
      // Delete main file
      if (attachment.url.isNotEmpty) {
        final Reference fileRef = _storage.refFromURL(attachment.url);
        await fileRef.delete();
      }
      
      // Delete thumbnail if exists
      if (attachment.thumbnailUrl != null) {
        final Reference thumbnailRef = _storage.refFromURL(attachment.thumbnailUrl!);
        await thumbnailRef.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete file attachment: $e');
    }
  }
} 