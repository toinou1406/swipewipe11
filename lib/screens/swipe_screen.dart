import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
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
  final CardSwiperController _swiperController = CardSwiperController();
  final ValueNotifier<Offset> _dragPosition = ValueNotifier(Offset.zero);

  app_media.Media? _lastSwipedMedia;
  String? _lastAction;

  final Map<String, File> _fileCache = {};
  bool _isPreloading = false;

  @override
  void dispose() {
    _swiperController.dispose();
    _dragPosition.dispose();
    super.dispose();
  }

  Future<void> _preloadNextMediaFiles() async {
    if (_isPreloading) return;
    if (mounted) setState(() { _isPreloading = true; });

    final mediaList = ref.read(swipeCardStateProvider).value ?? [];
    final upcomingMedia = mediaList.take(5);

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

  Future<bool> _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) async {
    _dragPosition.value = Offset.zero; // Reset position after swipe
    final media = ref.read(swipeCardStateProvider).value![previousIndex];

    if (direction == CardSwiperDirection.right) {
      _onSwipeRight();
    } else if (direction == CardSwiperDirection.left) {
      await _onSwipeLeft(media);
    } else if (direction == CardSwiperDirection.bottom) {
      await _onSwipeDown(media);
    }
    // The undo (top swipe) is handled by a separate gesture detector
    return true;
  }

  void _onSwipeRight() {
    ref.read(swipeCardStateProvider.notifier).removeFirst();
    setState(() {
      _lastSwipedMedia = null; // No undo for "keep"
      _lastAction = null;
    });
  }

  Future<void> _onSwipeLeft(app_media.Media media) async {
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
    ref.read(swipeCardStateProvider.notifier).removeFirst();
  }

  Future<void> _onUndo() async {
    if (_lastSwipedMedia == null || _lastAction == null) return;

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

    setState(() { _lastSwipedMedia = null; _lastAction = null; });
  }

  Future<void> _onSwipeDown(app_media.Media media) async {
    final albums = await ref.read(albumsProvider.future);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SwipeMenu(
        albums: albums,
        onAlbumSelected: (albumId) async {
          final dbHelper = ref.read(databaseHelperProvider);
          final updatedMedia = media.copyWith(albumId: albumId);
          await dbHelper.updateMedia(updatedMedia);

          setState(() { _lastSwipedMedia = updatedMedia; _lastAction = 'album'; });
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaListAsync = ref.watch(swipeCardStateProvider);

    ref.listen(swipeCardStateProvider, (prev, next) {
      if(next.value != null && next.value!.isNotEmpty) {
        _preloadNextMediaFiles();
      }
    });

    return Scaffold(
      body: mediaListAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (mediaList) {
          if (mediaList.isEmpty) {
            return const Center(child: Text('No more media to sort!'));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text('Photos to sort: ${mediaList.length}', style: Theme.of(context).textTheme.bodyMedium),
              ),
              Expanded(
                child: GestureDetector(
                  onVerticalDragEnd: (details) {
                    if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
                      _onUndo();
                    }
                  },
                  child: CardSwiper(
                    controller: _swiperController,
                    cardsCount: mediaList.length,
                    onSwipe: _onSwipe,
                    onDrag: (details, offset) => _dragPosition.value = offset,
                    duration: const Duration(milliseconds: 200),
                    backCardOffset: const Offset(0, 20),
                    scale: 0.9,
                    cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                      final media = mediaList[index];
                      final file = _fileCache[media.originalPath];
                      if (file == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return ValueListenableBuilder<Offset>(
                        valueListenable: _dragPosition,
                        builder: (context, position, child) {
                          return MediaCard(
                            mediaFile: file,
                            mediaType: media.mediaType,
                            position: index == 0 ? position : Offset.zero,
                            angle: index == 0 ? (position.dx / (MediaQuery.of(context).size.width / 2) * 0.2) : 0,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}