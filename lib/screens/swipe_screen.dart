import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:swipewipe10/data/database_helper.dart';
import 'package:swipewipe10/data/providers.dart';
import 'package:swipewipe10/models/media.dart' as app_media;
import 'package:swipewipe10/utils/theme.dart';
import 'package:swipewipe10/widgets/media_card.dart';
import 'package:swipewipe10/widgets/swipe_menu.dart';

class SwipeScreen extends ConsumerStatefulWidget {
  const SwipeScreen({super.key});

  @override
  ConsumerState<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends ConsumerState<SwipeScreen> {
  app_media.Media? _lastSwipedMedia;
  String? _lastAction; // 'delete', 'album'

  // Pre-fetch file data to avoid FutureBuilder in build method
  Map<String, File> _fileCache = {};
  bool _isPreloading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preloadMediaFiles();
  }

  Future<void> _preloadMediaFiles() async {
    if (_isPreloading) return;
    setState(() {
      _isPreloading = true;
    });

    final mediaList = ref.read(swipeCardStateProvider);
    for (final media in mediaList) {
      if (_fileCache.containsKey(media.originalPath)) continue;
      final asset = await AssetEntity.fromId(media.originalPath);
      if (asset != null) {
        final file = await asset.file;
        if (file != null) {
          _fileCache[media.originalPath] = file;
        }
      }
    }
    if (mounted) {
      setState(() {
        _isPreloading = false;
      });
    }
  }

  void _onSwipeRight() {
    ref.read(swipeCardStateProvider.notifier).removeCard();
  }

  void _onSwipeLeft(app_media.Media media) async {
    final dbHelper = ref.read(databaseHelperProvider);

    // 1. Mark as deleted in the local DB
    final updatedMedia = media.copyWith(deletedAt: DateTime.now());
    await dbHelper.updateMedia(updatedMedia);

    // 2. Check trash size and permanently delete oldest if necessary
    final trashedItems = await dbHelper.readLastTenTrashedMedia();
    if (trashedItems.length >= 10) {
      final oldestMedia = await dbHelper.readOldestTrashedMedia();
      if (oldestMedia != null) {
        // Use PhotoManager to request native OS deletion
        final List<String> deletedIds = await PhotoManager.editor.deleteWithIds([oldestMedia.originalPath]);
        if (deletedIds.isNotEmpty) {
          // If successful, remove from our DB
          await dbHelper.deleteMediaPermanently(oldestMedia.id!);
        }
      }
    }

    // 3. Update UI
    setState(() {
      _lastSwipedMedia = updatedMedia;
      _lastAction = 'delete';
    });
    ref.read(swipeCardStateProvider.notifier).removeCard();
  }

  void _onSwipeUp() async {
    if (_lastSwipedMedia == null || _lastAction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recent action to undo.')),
      );
      return;
    }

    final dbHelper = ref.read(databaseHelperProvider);
    app_media.Media mediaToRestore;

    if (_lastAction == 'delete') {
      mediaToRestore = _lastSwipedMedia!.copyWith(setDeletedAtToNull: true);
    } else if (_lastAction == 'album') {
      mediaToRestore = _lastSwipedMedia!.copyWith(setAlbumIdToNull: true);
    } else {
      return;
    }

    await dbHelper.updateMedia(mediaToRestore);
    ref.read(swipeCardStateProvider.notifier).undo(mediaToRestore);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Action undone.')),
    );

    setState(() {
      _lastSwipedMedia = null;
      _lastAction = null;
    });
  }

  void _onSwipeDown(app_media.Media media) async {
    final albums = await ref.read(albumsProvider.future);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SwipeMenu(
          albums: albums,
          onAlbumSelected: (albumId) async {
            final dbHelper = ref.read(databaseHelperProvider);
            final updatedMedia = media.copyWith(albumId: albumId);
            await dbHelper.updateMedia(updatedMedia);

            setState(() {
              _lastSwipedMedia = updatedMedia;
              _lastAction = 'album';
            });
            ref.read(swipeCardStateProvider.notifier).removeCard();
            Navigator.pop(context);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaList = ref.watch(swipeCardStateProvider);
    // Listen to the provider to trigger preloading when the list changes
    ref.listen(swipeCardStateProvider, (previous, next) {
      _preloadMediaFiles();
    });

    return Scaffold(
      body: Column(
        children: [
          // This progress bar is now just a placeholder as we don't track file sizes anymore
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Text('Photos to sort: ${mediaList.length}', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),

          Expanded(
            child: _isPreloading && mediaList.isNotEmpty
                ? const Center(child: CircularProgressIndicator())
                : mediaList.isEmpty
                    ? const Center(child: Text('No more media to sort!'))
                    : Stack(
                        alignment: Alignment.center,
                        children: mediaList.map((media) {
                          final file = _fileCache[media.originalPath];
                          if (file == null) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          return MediaCard(
                            mediaFile: file,
                            mediaType: media.mediaType,
                            onSwipeLeft: () => _onSwipeLeft(media),
                            onSwipeRight: _onSwipeRight,
                            onSwipeUp: _onSwipeUp,
                            onSwipeDown: () => _onSwipeDown(media),
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }
}