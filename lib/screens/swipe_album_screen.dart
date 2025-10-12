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

    try {
      final mediaList = ref.read(swipeCardStateProvider).value ?? [];
      if (mediaList.isEmpty) {
        if (mounted) setState(() { _isPreloading = false; });
        return;
      }
      
      // Preload only the first 10 items to ensure smooth swiping
      final itemsToPreload = mediaList.take(10).where(
        (media) => !_fileCache.containsKey(media.originalPath)
      ).toList();
      
      if (itemsToPreload.isEmpty) {
        if (mounted) setState(() { _isPreloading = false; });
        return;
      }
      
      debugPrint('Preloading ${itemsToPreload.length} media files');
      
      // Use a more efficient approach to load files in parallel
      final futures = <Future>[];
      
      for (final media in itemsToPreload) {
        futures.add(() async {
          try {
            final asset = await AssetEntity.fromId(media.originalPath);
            if (asset != null) {
              final file = await asset.file;
              if (file != null && mounted) {
                setState(() {
                  _fileCache[media.originalPath] = file;
                });
              }
            }
          } catch (e) {
            // Log errors for individual files
            debugPrint('Error preloading file ${media.originalPath}: ${e.toString()}');
          }
        }());
      }
      
      // Wait for all files to load, but with a timeout to prevent hanging
      await Future.wait(
        futures, 
        eagerError: false
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Preloading timed out after 10 seconds');
          return [];
        }
      );
      
      // Clean up cache to prevent memory issues, but keep more items for infinite scrolling
      if (_fileCache.length > 50) {
        final keysToRemove = _fileCache.keys.toList().sublist(0, _fileCache.length - 50);
        for (final key in keysToRemove) {
          _fileCache.remove(key);
        }
      }
    } catch (e) {
      debugPrint('Error in preloading: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() { _isPreloading = false; });
      }
    }
  }

  Future<bool> _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) async {
    _dragPosition.value = Offset.zero;
    
    // Verify the media list has items and the index is valid
    final mediaList = ref.read(swipeCardStateProvider).value;
    if (mediaList == null || mediaList.isEmpty || previousIndex >= mediaList.length) {
      return false;
    }
    
    final media = mediaList[previousIndex];
    
    try {
      if (direction == CardSwiperDirection.right) {
        _onSwipeRight();
      } else if (direction == CardSwiperDirection.left) {
        await _onSwipeLeft(media);
      } else if (direction == CardSwiperDirection.bottom) {
        await _onSwipeDown(media);
      }
      return true;
    } catch (e) {
      debugPrint('Error during swipe action: ${e.toString()}');
      return false;
    }
  }

  void _onSwipeRight() {
    ref.read(swipeHistoryProvider.notifier).state = null;
    ref.read(swipeCardStateProvider.notifier).removeFirst();
  }

  Future<void> _onSwipeLeft(app_media.Media media) async {
    final dbHelper = ref.read(databaseHelperProvider);
    final updatedMedia = media.copyWith(albumId: widget.albumId);
    await dbHelper.updateMedia(updatedMedia);

    ref.read(swipeHistoryProvider.notifier).state = SwipeAction(updatedMedia, 'add');
    ref.read(swipeCardStateProvider.notifier).removeFirst();
  }

  Future<void> _onUndo() async {
    final lastAction = ref.read(swipeHistoryProvider);
    if (lastAction == null) return;

    final dbHelper = ref.read(databaseHelperProvider);
    final mediaToRestore = lastAction.media.copyWith(setAlbumIdToNull: true);

    await dbHelper.updateMedia(mediaToRestore);
    ref.read(swipeCardStateProvider.notifier).undo(mediaToRestore);
    ref.read(swipeHistoryProvider.notifier).state = null;
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

          ref.read(swipeHistoryProvider.notifier).state = SwipeAction(updatedMedia, 'move');
          if (context.mounted) Navigator.pop(context);
          _swiperController.swipe(CardSwiperDirection.bottom);
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Force refresh the media list when the screen is first loaded
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Clear any existing cache
      _fileCache.clear();
      
      // Request permissions if needed
      final permissionState = await PhotoManager.requestPermissionExtend();
      if (permissionState.isAuth) {
        // Refresh media list
        ref.read(swipeCardStateProvider.notifier).refreshMedia();
      } else {
        // Show permission dialog if needed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photos permission is required to display your gallery'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaListAsync = ref.watch(swipeCardStateProvider);

    // Force preload images when media list changes
    ref.listen(swipeCardStateProvider, (prev, next) {
      if(next.value != null && next.value!.isNotEmpty) {
        // Immediately preload files when media list changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _preloadNextMediaFiles();
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter à l\'album'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Force refresh media and clear cache
              _fileCache.clear();
              ref.read(swipeCardStateProvider.notifier).refreshMedia();
            },
          ),
        ],
      ),
      body: mediaListAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Chargement de vos photos...'),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Erreur: $err'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _fileCache.clear();
                  ref.read(swipeCardStateProvider.notifier).refreshMedia();
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (mediaList) {
          if (mediaList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Aucune photo à trier !'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      _fileCache.clear();
                      ref.read(swipeCardStateProvider.notifier).refreshMedia();
                    },
                    child: const Text('Rafraîchir'),
                  ),
                ],
              ),
            );
          }
          
          // Trigger preload if not already preloading
          if (!_isPreloading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _preloadNextMediaFiles();
            });
          }
          
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Photos à trier: ${mediaList.length}', 
                      style: Theme.of(context).textTheme.bodyMedium),
                    if (_isPreloading)
                      const SizedBox(
                        width: 16, 
                        height: 16, 
                        child: CircularProgressIndicator(strokeWidth: 2)
                      ),
                  ],
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onVerticalDragUpdate: (details) {
                    // This gesture detector is only for the visual indicator for "undo"
                    if (details.delta.dy < -5) { // Swiping up
                      _dragPosition.value = Offset(0, details.localPosition.dy - (MediaQuery.of(context).size.height / 3));
                    }
                  },
                  onVerticalDragEnd: (details) {
                    _dragPosition.value = Offset.zero;
                    if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
                      _onUndo();
                    }
                  },
                  child: CardSwiper(
                    controller: _swiperController,
                    cardsCount: mediaList.length,
                    onSwipe: _onSwipe,
                    allowedSwipeDirection: const AllowedSwipeDirection.symmetric(horizontal: true, vertical: true),
                    duration: const Duration(milliseconds: 200),
                    backCardOffset: const Offset(0, 20),
                    scale: 0.9,
                    cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                      // Preload more media when we're getting close to the end
                      if (index >= mediaList.length - 5) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          // This will trigger loading more media if needed
                          ref.read(swipeCardStateProvider.notifier).removeFirst();
                          ref.read(swipeCardStateProvider.notifier).undo(mediaList[0]);
                        });
                      }
                      
                      // Preload images for the next few cards
                      if (index < 10) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _preloadNextMediaFiles();
                        });
                      }
                      
                      final media = mediaList[index];
                      final file = _fileCache[media.originalPath];
                      
                      // If file is not in cache, try to load it immediately
                      if (file == null) {
                        // Trigger loading for this specific file if not already loading
                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                          try {
                            final asset = await AssetEntity.fromId(media.originalPath);
                            if (asset != null) {
                              final loadedFile = await asset.file;
                              if (loadedFile != null && mounted) {
                                setState(() {
                                  _fileCache[media.originalPath] = loadedFile;
                                });
                              }
                            }
                          } catch (e) {
                            debugPrint('Error loading file in builder: ${e.toString()}');
                          }
                        });
                        
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Chargement...'),
                            ],
                          ),
                        );
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