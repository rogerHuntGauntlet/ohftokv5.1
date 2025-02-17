import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadFile(File file, String folder) async {
    // Create a unique filename using timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(file.path);
    final filename = '$timestamp$extension';

    // Create the storage reference
    final ref = _storage.ref().child(folder).child(filename);

    // Upload the file
    final uploadTask = ref.putFile(file);

    // Wait for the upload to complete and get the download URL
    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    return downloadUrl;
  }

  Future<void> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      print('Error deleting file: $e');
      // Ignore errors since the file might have already been deleted
    }
  }
} 