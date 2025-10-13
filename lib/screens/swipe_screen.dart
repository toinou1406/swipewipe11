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

  final Map<String, File> _fileCache = {};
  final Map<int, Widget> _widgetCache = {}; // Cache pour les widgets des cartes
  bool _isPreloading = false;
  bool _isProcessingSwipe = false; // Flag pour éviter les swipes multiples simultanés

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
      
      final itemsToPreload = mediaList.take(20).where(
        (media) => !_fileCache.containsKey(media.originalPath)
      ).toList();
      
      if (itemsToPreload.isEmpty) {
        if (mounted) setState(() { _isPreloading = false; });
        return;
      }
      
      debugPrint('Préchargement de ${itemsToPreload.length} fichiers médias');
      
      final mediaRepo = ref.read(mediaRepositoryProvider);
      
      for (final item in itemsToPreload) {
        try {
          final file = await mediaRepo.getFileForMedia(item);
          if (file != null && mounted) {
            setState(() {
              _fileCache[item.originalPath] = file;
            });
          }
        } catch (e) {
          debugPrint('Erreur de préchargement pour ${item.originalPath}: $e');
        }
      }
      
      if (_fileCache.length > 100) {
        final currentMediaPaths = mediaList.take(20).map((m) => m.originalPath).toSet();
        final keysToRemove = _fileCache.keys.where((key) => !currentMediaPaths.contains(key)).toList();
        
        if (keysToRemove.length > 20) {
          final keysToRemoveNow = keysToRemove.sublist(0, keysToRemove.length - 20);
          for (final key in keysToRemoveNow) {
            _fileCache.remove(key);
          }
        }
      }
      
      if (mediaList.length < 10) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(swipeCardStateProvider.notifier).loadMore();
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du préchargement: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() { _isPreloading = false; });
      }
    }
  }

  Future<bool> _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) async {
    if (_isProcessingSwipe) {
      debugPrint('Swipe ignoré : traitement en cours');
      return false;
    }
    
    _isProcessingSwipe = true;
    
    try {
      _dragPosition.value = Offset.zero;
      _widgetCache.remove(previousIndex);
      
      final mediaList = ref.read(swipeCardStateProvider).value;
      if (mediaList == null || mediaList.isEmpty) {
        debugPrint('Liste de médias vide ou null');
        ref.read(swipeCardStateProvider.notifier).loadMore();
        return false;
      }
    
      final media = mediaList[0];
      debugPrint('Photo qui sera traitée (index 0): ${media.originalPath}');
      
      if (mediaList.length > 1) {
        final nextMediaItems = mediaList.sublist(1).take(3).toList();
        if (nextMediaItems.isNotEmpty) {
          final mediaRepo = ref.read(mediaRepositoryProvider);
          for (final item in nextMediaItems) {
            mediaRepo.getFileForMedia(item).then((file) {
              if (file != null && mounted) {
                setState(() {
                  _fileCache[item.originalPath] = file;
                });
              }
            }).catchError((e) {
              debugPrint('Erreur préchargement: $e');
            });
          }
        }
      }

      try {
        if (direction == CardSwiperDirection.right) {
          await _onSwipeRight(0);
        } else if (direction == CardSwiperDirection.left) {
          await _onSwipeLeft(media, 0);
        } else if (direction == CardSwiperDirection.bottom) {
          await _onSwipeDown(media, 0);
          return false;
        }
        
        _preloadNextMediaFiles();
        return true;
      } catch (e) {
        debugPrint('Erreur pendant l\'action de swipe: ${e.toString()}');
        return false;
      }
    } finally {
      _isProcessingSwipe = false;
    }
  }

  Future<void> _onSwipeRight(int index) async {
    ref.read(swipeHistoryProvider.notifier).state = null;
    await ref.read(swipeCardStateProvider.notifier).removeAt(index);
  }

  Future<void> _onSwipeLeft(app_media.Media media, int index) async {
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

    ref.read(swipeHistoryProvider.notifier).state = SwipeAction(updatedMedia, 'delete');
    await ref.read(swipeCardStateProvider.notifier).removeAt(index);
  }

  Future<void> _onUndo() async {
    final lastAction = ref.read(swipeHistoryProvider);
    if (lastAction == null) return;

    final dbHelper = ref.read(databaseHelperProvider);
    app_media.Media mediaToRestore;

    if (lastAction.action == 'delete') {
      mediaToRestore = lastAction.media.copyWith(setDeletedAtToNull: true);
    } else if (lastAction.action == 'album') {
      mediaToRestore = lastAction.media.copyWith(setAlbumIdToNull: true);
    } else {
      return;
    }

    await dbHelper.updateMedia(mediaToRestore);
    await ref.read(swipeCardStateProvider.notifier).undo(mediaToRestore);
    ref.read(swipeHistoryProvider.notifier).state = null;
  }

  Future<void> _onSwipeDown(app_media.Media media, int index) async {
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

          ref.read(swipeHistoryProvider.notifier).state = SwipeAction(updatedMedia, 'album');
          await ref.read(swipeCardStateProvider.notifier).removeAt(index);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _fileCache.clear();
      _widgetCache.clear();
      
      final permissionState = await PhotoManager.requestPermissionExtend();
      if (!permissionState.isAuth) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('L\'accès aux photos est nécessaire pour afficher votre galerie'),
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

    ref.listen(swipeCardStateProvider, (prev, next) {
      if(next.value != null && next.value!.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _preloadNextMediaFiles();
        });
      }
    });

    return Scaffold(
      body: mediaListAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Préparation de vos photos...'),
              SizedBox(height: 8),
              Text('Cela ne prendra que quelques secondes', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Impossible de charger vos photos'),
              Text('Erreur: $err', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _fileCache.clear();
                  _widgetCache.clear();
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
                  const Text('Toutes vos photos sont triées !'),
                  const SizedBox(height: 8),
                  const Text('Aucune photo à trier pour le moment', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      _fileCache.clear();
                      ref.read(swipeCardStateProvider.notifier).refreshMedia();
                    },
                    child: const Text('Rechercher de nouvelles photos'),
                  ),
                ],
              ),
            );
          }
          
          if (!_isPreloading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _preloadNextMediaFiles();
            });
          }
          
          return GestureDetector(
                  onVerticalDragUpdate: (details) {
                    if (details.delta.dy < -5) {
                      _dragPosition.value = Offset(0, details.localPosition.dy - (MediaQuery.of(context).size.height / 3));
                    }
                  },
                  onVerticalDragEnd: (details) {
                    _dragPosition.value = Offset.zero;
                    if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
                      _onUndo();
                    }
                  },
                  child: mediaList.isEmpty 
                  ? const Center(
                      child: Text('Chargement de nouvelles photos...', 
                        style: TextStyle(color: Colors.white))
                    )
                  : CardSwiper(
                    controller: _swiperController,
                    cardsCount: mediaList.length,
                    onSwipe: _onSwipe,
                    allowedSwipeDirection: const AllowedSwipeDirection.symmetric(horizontal: true, vertical: true),
                    duration: const Duration(milliseconds: 100),
                    backCardOffset: const Offset(0, 10),
                    scale: 0.98,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    numberOfCardsDisplayed: 3,
                    threshold: 40,
                    isLoop: false,
                    maxAngle: 25,
                    cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                      if (index >= mediaList.length) {
                        return const Center(
                          child: Text('Chargement...', style: TextStyle(color: Colors.white))
                        );
                      }
                      
                      final media = mediaList[index];
                      final file = _fileCache[media.originalPath];
                      
                      if (index == 0 && !_isPreloading) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _preloadNextMediaFiles();
                          if (mediaList.length < 10) {
                            final currentList = ref.read(swipeCardStateProvider).value ?? [];
                            if (currentList.isNotEmpty) {
                              ref.read(swipeCardStateProvider.notifier).loadMore();
                            }
                          }
                        });
                      }
                      
                      if (file == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                          try {
                            final mediaRepo = ref.read(mediaRepositoryProvider);
                            final loadedFile = await mediaRepo.getFileForMedia(media);
                            if (loadedFile != null && mounted) {
                              setState(() {
                                _fileCache[media.originalPath] = loadedFile;
                              });
                            }
                          } catch (e) {
                            debugPrint('Erreur de chargement: ${e.toString()}');
                          }
                        });
                        
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(strokeWidth: 2),
                              const SizedBox(height: 16),
                              Text(
                                'Chargement...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      if (index > 0 && _widgetCache.containsKey(index)) {
                        return _widgetCache[index]!;
                      }
                      
                      Widget cardWidget;
                      
                      if (index == 0) {
                        cardWidget = ValueListenableBuilder<Offset>(
                          valueListenable: _dragPosition,
                          builder: (context, position, child) {
                            return MediaCard(
                              mediaFile: file,
                              mediaType: media.mediaType,
                              position: position,
                              angle: position.dx / (MediaQuery.of(context).size.width / 2) * 0.2,
                            );
                          },
                        );
                      } else {
                        cardWidget = MediaCard(
                          mediaFile: file,
                          mediaType: media.mediaType,
                          position: Offset.zero,
                          angle: 0,
                        );
                        _widgetCache[index] = cardWidget;
                      }
                      
                      return cardWidget;
                    },
                  ),
                );
        },
      ),
    );
  }
}