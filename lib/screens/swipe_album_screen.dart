import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:swipewipe10/data/providers.dart';
import 'package:swipewipe10/models/media.dart' as app_media;
import 'package:swipewipe10/widgets/media_card.dart';
import 'package:swipewipe10/widgets/swipe_menu.dart';

class SwipeAlbumScreen extends ConsumerStatefulWidget {
  final int albumId;

  const SwipeAlbumScreen({super.key, required this.albumId});

  @override
  ConsumerState<SwipeAlbumScreen> createState() => _SwipeAlbumScreenState();
}

class _SwipeAlbumScreenState extends ConsumerState<SwipeAlbumScreen> {
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
    _dragPosition.value = Offset.zero;
    final media = ref.read(swipeCardStateProvider).value![previousIndex];

    if (direction == CardSwiperDirection.right) {
      _onSwipeRight();
    } else if (direction == CardSwiperDirection.left) {
      await _onSwipeLeft(media);
    } else if (direction == CardSwiperDirection.bottom) {
      await _onSwipeDown(media);
    }
    return true;
  }

  void _onSwipeRight() {
    ref.read(swipeCardStateProvider.notifier).removeFirst();
    setState(() {
      _lastSwipedMedia = null;
      _lastAction = null;
    });
  }

  Future<void> _onSwipeLeft(app_media.Media media) async {
    final dbHelper = ref.read(databaseHelperProvider);
    final updatedMedia = media.copyWith(albumId: widget.albumId);
    await dbHelper.updateMedia(updatedMedia);

    setState(() {
      _lastSwipedMedia = updatedMedia;
      _lastAction = 'add';
    });
    ref.read(swipeCardStateProvider.notifier).removeFirst();
  }

  Future<void> _onUndo() async {
    if (_lastSwipedMedia == null || _lastAction == null) return;

    final dbHelper = ref.read(databaseHelperProvider);
    final lastSwiped = _lastSwipedMedia!;
    final mediaToRestore = lastSwiped.copyWith(setAlbumIdToNull: true);

    await dbHelper.updateMedia(mediaToRestore);
    ref.read(swipeCardStateProvider.notifier).undo(mediaToRestore);

    setState(() { _lastSwipedMedia = null; _lastAction = null; });
  }

  Future<void> _onSwipeDown(app_media.Media media) async {
    final allAlbums = await ref.read(albumsProvider.future);
    final otherAlbums = allAlbums.where((album) => album.id != widget.albumId).toList();

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SwipeMenu(
        albums: otherAlbums,
        onAlbumSelected: (newAlbumId) async {
          final dbHelper = ref.read(databaseHelperProvider);
          final updatedMedia = media.copyWith(albumId: newAlbumId);
          await dbHelper.updateMedia(updatedMedia);

          setState(() { _lastSwipedMedia = updatedMedia; _lastAction = 'move'; });
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
      appBar: AppBar(title: const Text('Add to Album')),
      body: mediaListAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (mediaList) {
          if (mediaList.isEmpty) {
            return const Center(child: Text('No more media to sort!'));
          }
          return GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
                _onUndo();
              }
            },
            child: CardSwiper(
              controller: _swiperController,
              cardsCount: mediaList.length,
              onSwipe: _onSwipe,
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
          );
        },
      ),
    );
  }
}