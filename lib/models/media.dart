import 'package:photo_manager/photo_manager.dart';
import 'package:path/path.dart' as p;

class Media {
  final int? id;
  final String originalPath; // This is the asset ID from photo_manager
  final String filename;
  final String mediaType; // 'photo' or 'video'
  final int? albumId;
  final DateTime? deletedAt; // Null if not in trash

  const Media({
    this.id,
    required this.originalPath,
    required this.filename,
    required this.mediaType,
    this.albumId,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'original_path': originalPath,
      'filename': filename,
      'media_type': mediaType,
      'album_id': albumId,
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory Media.fromMap(Map<String, dynamic> map) {
    return Media(
      id: map['id'] as int?,
      originalPath: map['original_path'] as String,
      filename: map['filename'] as String,
      mediaType: map['media_type'] as String,
      albumId: map['album_id'] as int?,
      deletedAt: map['deleted_at'] == null ? null : DateTime.parse(map['deleted_at'] as String),
    );
  }

  // Helper factory to create a Media object directly from an AssetEntity
  factory Media.fromAsset(AssetEntity asset) {
    return Media(
      originalPath: asset.id,
      filename: asset.title ?? 'Untitled', // Use title as a fallback for filename
      mediaType: asset.type == AssetType.video ? 'video' : 'photo',
    );
  }

  Media copyWith({
    int? id,
    String? originalPath,
    String? filename,
    String? mediaType,
    int? albumId,
    DateTime? deletedAt,
    bool setAlbumIdToNull = false,
    bool setDeletedAtToNull = false,
  }) {
    return Media(
      id: id ?? this.id,
      originalPath: originalPath ?? this.originalPath,
      filename: filename ?? this.filename,
      mediaType: mediaType ?? this.mediaType,
      albumId: setAlbumIdToNull ? null : albumId ?? this.albumId,
      deletedAt: setDeletedAtToNull ? null : deletedAt ?? this.deletedAt,
    );
  }
}