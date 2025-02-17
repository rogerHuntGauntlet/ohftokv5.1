import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../models/message.dart';
import '../../../services/message_attachment_service.dart';

class MessageAttachmentWidget extends StatelessWidget {
  final Function(FileAttachment) onFileSelected;
  final Function(LocationInfo) onLocationSelected;
  final MessageAttachmentService attachmentService;

  const MessageAttachmentWidget({
    Key? key,
    required this.onFileSelected,
    required this.onLocationSelected,
    required this.attachmentService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.attach_file),
          onPressed: () => _showAttachmentOptions(context),
        ),
        IconButton(
          icon: const Icon(Icons.location_on),
          onPressed: () => _handleLocationSharing(context),
        ),
      ],
    );
  }

  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text('Photo'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(context, ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Camera'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(context, ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_present),
            title: const Text('Document'),
            onTap: () {
              Navigator.pop(context);
              _pickFile(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (image != null) {
        final file = File(image.path);
        final fileAttachment = await attachmentService.uploadFile(
          file,
          'temp_conversation_id', // Replace with actual conversation ID
        );
        onFileSelected(fileAttachment);
      }
    } catch (e) {
      _showErrorDialog(context, 'Failed to pick image: $e');
    }
  }

  Future<void> _pickFile(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null) {
        final file = File(result.files.single.path!);
        final fileAttachment = await attachmentService.uploadFile(
          file,
          'temp_conversation_id', // Replace with actual conversation ID
        );
        onFileSelected(fileAttachment);
      }
    } catch (e) {
      _showErrorDialog(context, 'Failed to pick file: $e');
    }
  }

  Future<void> _handleLocationSharing(BuildContext context) async {
    try {
      final locationInfo = await attachmentService.getCurrentLocation();
      _showLocationPreview(context, locationInfo);
    } catch (e) {
      _showErrorDialog(context, 'Failed to get location: $e');
    }
  }

  void _showLocationPreview(BuildContext context, LocationInfo locationInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Location'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      locationInfo.latitude,
                      locationInfo.longitude,
                    ),
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('current_location'),
                      position: LatLng(
                        locationInfo.latitude,
                        locationInfo.longitude,
                      ),
                    ),
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                locationInfo.address ?? 'Unknown location',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onLocationSelected(locationInfo);
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
} 