import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Stores the sailor's profile photo entirely on-device: picked from the
/// gallery, copied into the app's local documents directory under a fixed
/// filename (so a new pick simply overwrites the old one), and never
/// uploaded anywhere — this never touches the backend.
class ProfilePhotoService {
  ProfilePhotoService({
    ImagePicker? picker,
    Future<Directory> Function()? directoryProvider,
  }) : _picker = picker ?? ImagePicker(),
       _directoryProvider = directoryProvider ?? getApplicationDocumentsDirectory;

  final ImagePicker _picker;

  /// Where the photo file lives. Overridable for tests so they exercise the
  /// real file-copy logic against a temp directory rather than the device's
  /// actual app-documents directory (which needs a platform channel
  /// `path_provider` has no mock for in plain `flutter test`).
  final Future<Directory> Function() _directoryProvider;

  static const String _fileName = 'profile_photo.jpg';

  Future<File> _targetFile() async {
    final dir = await _directoryProvider();
    return File('${dir.path}/$_fileName');
  }

  /// The currently saved photo, or null if none has been picked yet.
  Future<File?> currentPhoto() async {
    final file = await _targetFile();
    return file.existsSync() ? file : null;
  }

  /// Opens the gallery picker. Copies whatever the sailor picks into local
  /// storage (overwriting any previous photo) and returns the saved file.
  /// Returns null if they cancel the picker without choosing anything.
  Future<File?> pickFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      // Capped so a full-resolution camera-roll photo doesn't balloon
      // on-device storage; still plenty sharp for a 96px avatar circle.
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return null;
    final target = await _targetFile();
    final bytes = await picked.readAsBytes();
    return target.writeAsBytes(bytes, flush: true);
  }

  /// Deletes the saved photo, if any, reverting to the default avatar.
  Future<void> clear() async {
    final file = await _targetFile();
    if (file.existsSync()) await file.delete();
  }
}
