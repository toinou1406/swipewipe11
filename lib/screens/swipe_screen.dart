import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:swipewipe10/data/providers.dart';
import 'package:swipewipe10/models/media.dart' as app_media;
import 'package:swipewipe10/widgets/media_card.dart';
import 'package:swipewipe10/widgets/swipe_menu.dart';

class SwipeScreen extends ConsumerStatefulWidget {
  const SwipeScreen({super.key});

  @override
  ConsumerState<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends ConsumerState<SwipeScreen> {
  app_media.Media? _lastSwipedMedia;
  String? _lastAction;

  final Map<String, File> _fileCache = {};
  bool _isPreloading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preloadNextMediaFiles();
  }

  Future<void> _preloadNextMediaFiles({int count = 5}) async {
    if (_isPreloading) return;
    setState(() { _isPreloading = true; });

    final mediaList = ref.read(swipeCardStateProvider);
    final upcomingMedia = mediaList.take(count);

    for (final media in upcomingMedia) {
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
      setState(() { _isPreloading = false; });
    }
  }

  void _handleSwipe(DragEndDetails details, app_media.Media media) {
    if (details.primaryVelocity == null) return;

    // Swipe right (keep)
    if (details.primaryVelocity! > 200) {
      _onSwipeRight();
    }
    // Swipe left (delete)
    else if (details.primaryVelocity! < -200) {
      _onSwipeLeft(media);
    }
    // Swipe up (undo)
    else if (details.primaryVelocity! < -500 && details.velocity.pixelsPerSecond.dx.abs() < details.velocity.pixelsPerSecond.dy.abs()){
       _onSwipeUp();
    }
    // Swipe down (album menu)
    else if (details.primaryVelocity! > 500 && details.velocity.pixelsPerSecond.dx.abs() < details.velocity.pixelsPerSecond.dy.abs()){
       _onSwipeDown(media);
    }
  }

  void _onSwipeRight() {
    ref.read(swipeCardStateProvider.notifier).removeCard();
  }

  void _onSwipeLeft(app_media.Media media) async {
    final dbHelper = ref.read(databaseHelperProvider);
    final updatedMedia = media.copyWith(deletedAt: DateTime.now());
    await dbHelper.updateMedia(updatedMedia);

    final trashedItems = await dbHelper.readLastTenTrashedMedia();
    if (trashedItems.length >= 10) {
      final oldestMedia = await dbHelper.readOldestTrashedMedia();
      if (oldestMedia != null) {
        final List<String> deletedIds = await PhotoManager.editor.deleteWithIds([oldestMedia.originalPath]);
        if (deletedIds.isNotEmpty) {
          await dbHelper.deleteMediaPermanently(oldestMedia.id!);
        }
      }
    }

    setState(() {
      _lastSwipedMedia = updatedMedia;
      _lastAction = 'delete';
    });
    ref.read(swipeCardStateProvider.notifier).removeCard();
  }

  void _onSwipeUp() async {
    if (_lastSwipedMedia == null || _lastAction == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recent action to undo.')),
      );
      return;
    }

    final dbHelper = ref.read(databaseHelperProvider);
    final lastSwiped = _lastSwipedMedia!;
    app_media.Media mediaToRestore;

    if (_lastAction == 'delete') {
      mediaToRestore = lastSwiped.copyWith(setDeletedAtToNull: true);
    } else if (_lastAction == 'album') {
      mediaToRestore = lastSwiped.copyWith(setAlbumIdToNull: true);
    } else {
      return;
    }

    await dbHelper.updateMedia(mediaToRestore);
    ref.read(swipeCardStateProvider.notifier).undo(mediaToRestore);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action undone.')));

    setState(() { _lastSwipedMedia = null; _lastAction = null; });
  }

  void _onSwipeDown(app_media.Media media) async {
    final albums = await ref.read(albumsProvider.future);
    if (!mounted) return;
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

            setState(() { _lastSwipedMedia = updatedMedia; _lastAction = 'album'; });
            ref.read(swipeCardStateProvider.notifier).removeCard();
            if (context.mounted) Navigator.pop(context);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaList = ref.watch(swipeCardStateProvider);
    ref.listen(swipeCardStateProvider, (previous, next) {
      _preloadNextMediaFiles();
    });

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Text('Photos to sort: ${mediaList.length}', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Expanded(
            child: _isPreloading && mediaList.isNotEmpty && _fileCache.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : mediaList.isEmpty
                    ? const Center(child: Text('No more media to sort!'))
                    : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Stack(
                          alignment: Alignment.center,
                          children: List.generate(
                            mediaList.take(3).length, // Build only a few cards
                            (index) {
                              final media = mediaList[index];
                              final file = _fileCache[media.originalPath];
                              if (file == null) return const SizedBox.shrink();

                              return Transform.translate(
                                offset: Offset(0, 10.0 * index), // Stack effect
                                child: MediaCard(
                                  mediaFile: file,
                                  mediaType: media.mediaType,
                                  isTopCard: index == 0,
                                  onSwipe: (details) => _handleSwipe(details, media),
                                ),
                              );
                            },
                          ).reversed.toList(),
                        ),
                    ),
          ),
        ],
      ),
    );
  }
}