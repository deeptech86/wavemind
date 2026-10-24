import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidewell_app/data/profile_photo_service.dart';

void main() {
  late Directory tempDir;
  late ProfilePhotoService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('profile_photo_test');
    service = ProfilePhotoService(directoryProvider: () async => tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('currentPhoto is null before anything has ever been saved', () async {
    expect(await service.currentPhoto(), isNull);
  });

  test('clear on an unset photo is a harmless no-op', () async {
    await service.clear();
    expect(await service.currentPhoto(), isNull);
  });

  test('a saved file is found by currentPhoto at the expected path', () async {
    final file = File('${tempDir.path}/profile_photo.jpg');
    await file.writeAsBytes([1, 2, 3]);

    final photo = await service.currentPhoto();

    expect(photo, isNotNull);
    expect(photo!.path, file.path);
    expect(await photo.readAsBytes(), [1, 2, 3]);
  });

  test('clear deletes a previously saved photo', () async {
    final file = File('${tempDir.path}/profile_photo.jpg');
    await file.writeAsBytes([1, 2, 3]);
    expect(await service.currentPhoto(), isNotNull);

    await service.clear();

    expect(await service.currentPhoto(), isNull);
    expect(file.existsSync(), isFalse);
  });
}
