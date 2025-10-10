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
  app_media.Media? _lastSwipedMedia;
  String? _lastAction;

  final Map<String, File> _fileCache = {};
  bool _isPreloading = false;
  final CardSwiperController _swiperController = CardSwiperController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preloadNextMediaFiles();
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  Future<void> _preloadNextMediaFiles({int count = 5}) async {
    if (_isPreloading) return;
    if (mounted) setState(() { _isPreloading = true; });

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

  bool _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) {
    final media = ref.read(swipeCardStateProvider)[previousIndex];

    switch (direction) {
      case CardSwiperDirection.right:
        _onSwipeRight();
        break;
      case CardSwiperDirection.left:
        _onSwipeLeft(media);
        break;
      case CardSwiperDirection.top:
        _onSwipeUp();
        break;
      case CardSwiperDirection.bottom:
        _onSwipeDown(media);
        break;
      case CardSwiperDirection.none:
        break;
    }
    return true;
  }

  void _onSwipeRight() {
    ref.read(swipeCardStateProvider.notifier).removeCard();
  }

  void _onSwipeLeft(app_media.Media media) async {
    final dbHelper = ref.read(databaseHelperProvider);
    final updatedMedia = media.copyWith(albumId: widget.albumId);
    await dbHelper.updateMedia(updatedMedia);

    setState(() {
      _lastSwipedMedia = updatedMedia;
      _lastAction = 'add';
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
    final mediaToRestore = lastSwiped.copyWith(setAlbumIdToNull: true);

    await dbHelper.updateMedia(mediaToRestore);
    ref.read(swipeCardStateProvider.notifier).undo(mediaToRestore);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action undone.')));

    setState(() { _lastSwipedMedia = null; _lastAction = null; });
  }

  void _onSwipeDown(app_media.Media media) async {
    final allAlbums = await ref.read(albumsProvider.future);
    final otherAlbums = allAlbums.where((album) => album.id != widget.albumId).toList();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SwipeMenu(
          albums: otherAlbums,
          onAlbumSelected: (newAlbumId) async {
            final dbHelper = ref.read(databaseHelperProvider);
            final updatedMedia = media.copyWith(albumId: newAlbumId);
            await dbHelper.updateMedia(updatedMedia);

            setState(() { _lastSwipedMedia = updatedMedia; _lastAction = 'move'; });
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
      appBar: AppBar(
        title: const Text('Add to Album'),
      ),
      body: (_isPreloading && mediaList.isNotEmpty && _fileCache.isEmpty) || (mediaList.isNotEmpty && _fileCache[mediaList.first.originalPath] == null)
          ? const Center(child: CircularProgressIndicator())
          : mediaList.isEmpty
              ? const Center(child: Text('No more media to sort!'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CardSwiper(
                    controller: _swiperController,
                    cardsCount: mediaList.length,
                    onSwipe: _onSwipe,
                    duration: const Duration(milliseconds: 150),
                    backCardOffset: const Offset(0, 20),
                    scale: 0.9,
                    cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                      final media = mediaList[index];
                      final file = _fileCache[media.originalPath];
                      if (file == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return MediaCard(
                        mediaFile: file,
                        mediaType: media.mediaType,
                      );
                    },
                  ),
                ),
    );
  }
}