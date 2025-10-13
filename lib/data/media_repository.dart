import 'dart:io';
import 'package:photo_manager/photo_manager.dart';
import 'package:path/path.dart' as p;
import 'package:swipewipe10/data/database_helper.dart';
import 'package:swipewipe10/models/media.dart' as app_media;

class MediaRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Fetches all media from the device storage and syncs them with the local DB.
  // This should be called only when necessary (e.g., first app launch, or manual refresh).
  Future<void> syncMediaWithDatabase() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.hasAccess) {
      // Handle the case where permission is not granted.
      // We can add more robust error handling or logging here if needed.
      return;
    }

    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
    );

    final db = await _dbHelper.database;

    for (final path in paths) {
      // We want to avoid system folders like "WhatsApp" or ".thumbnails"
      // This is a simple filter, can be improved.
      if (path.name.toLowerCase().contains('whatsapp')) continue;

      final List<AssetEntity> assets = await path.getAssetListRange(start: 0, end: path.assetCount);

      for (final asset in assets) {
        // Check if the media already exists in the database
        final List<Map<String, dynamic>> existing = await db.query(
          'medias',
          where: 'original_path = ?',
          whereArgs: [asset.id], // Using asset.id as a unique path identifier
        );

        if (existing.isEmpty) {
          final file = await asset.file;
          if (file != null) {
            // If not, insert it
            final newMedia = app_media.Media(
              originalPath: asset.id,
              filename: p.basename(file.path),
              mediaType: asset.type == AssetType.video ? 'video' : 'photo',
            );
            await _dbHelper.createMedia(newMedia);
          }
        }
      }
    }
  }

  Future<List<app_media.Media>> getUnsortedMedia() async {
    return _dbHelper.readUnsortedMedia();
  }

  Future<File?> getFileForMedia(app_media.Media media) async {
    final AssetEntity? asset = await AssetEntity.fromId(media.originalPath);
    if (asset == null) return null;
    return asset.file;
  }
}