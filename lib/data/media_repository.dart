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

      final int assetCount = path.assetCount;
      const int pageSize = 100; // Process 100 assets at a time

      for (int i = 0; i < assetCount; i += pageSize) {
        final List<AssetEntity> assets = await path.getAssetListRange(
          start: i,
          end: i + pageSize,
        );

        for (final asset in assets) {
          // Check if the media already exists in the database
          final List<Map<String, dynamic>> existing = await db.query(
            'medias',
            where: 'original_path = ?',
            whereArgs: [asset.id],
          );

          if (existing.isEmpty) {
            // Use the new factory method for cleaner code
            final newMedia = app_media.Media.fromAsset(asset);
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
    try {
      final AssetEntity? asset = await AssetEntity.fromId(media.originalPath);
      if (asset == null) {
        print('Error: Could not find asset with ID ${media.originalPath}');
        return null;
      }
      return await asset.file;
    } catch (e) {
      print('Error getting file for media ${media.originalPath}: $e');
      return null;
    }
  }
}