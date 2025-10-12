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
      
      // Précharger plus d'éléments pour assurer un défilement fluide
      // Augmenter à 20 pour avoir plus d'images préchargées
      final itemsToPreload = mediaList.take(20).where(
        (media) => !_fileCache.containsKey(media.originalPath)
      ).toList();
      
      if (itemsToPreload.isEmpty) {
        if (mounted) setState(() { _isPreloading = false; });
        return;
      }
      
      debugPrint('Préchargement de ${itemsToPreload.length} fichiers médias');
      
      // Prioriser les 3 premières images pour un chargement immédiat
      final List<app_media.Media> priorityItems = itemsToPreload.take(3).toList();
      final List<app_media.Media> regularItems = itemsToPreload.length > 3 ? itemsToPreload.sublist(3) : <app_media.Media>[];
      
      final mediaRepo = ref.read(mediaRepositoryProvider);
      
      // Charger les fichiers un par un et les ajouter au cache
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
      
      // Conserver plus d'éléments en cache pour éviter les rechargements
      if (_fileCache.length > 100) { // Augmenter encore la taille du cache
        // Garder les 20 premiers éléments de la liste actuelle
        final currentMediaPaths = mediaList.take(20).map((m) => m.originalPath).toSet();
        
        // Identifier les clés à supprimer (celles qui ne sont pas dans les 20 premiers éléments)
        final keysToRemove = _fileCache.keys.where((key) => !currentMediaPaths.contains(key)).toList();
        
        // Ne supprimer que si nous avons trop d'éléments
        if (keysToRemove.length > 20) {
          final keysToRemoveNow = keysToRemove.sublist(0, keysToRemove.length - 20);
          for (final key in keysToRemoveNow) {
            _fileCache.remove(key);
          }
        }
      }
      
      // Précharger plus de médias si nécessaire
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
    // Bloquer les swipes multiples simultanés
    if (_isProcessingSwipe) {
      debugPrint('Swipe ignoré : traitement en cours');
      return false;
    }
    
    _isProcessingSwipe = true;
    
    try {
      // Réinitialiser la position de glissement immédiatement
      _dragPosition.value = Offset.zero;
      
      // Nettoyer le cache de widgets pour la carte qui vient d'être swipée
      _widgetCache.remove(previousIndex);
      
      // Vérifier que la liste de médias contient des éléments
      final mediaList = ref.read(swipeCardStateProvider).value;
      if (mediaList == null || mediaList.isEmpty) {
        debugPrint('Liste de médias vide ou null');
        // Essayer de charger plus de médias automatiquement
        ref.read(swipeCardStateProvider.notifier).loadMore();
        return false;
      }
    
    debugPrint('=== SWIPE DEBUG ===');
    debugPrint('previousIndex: $previousIndex, currentIndex: $currentIndex');
    debugPrint('mediaList.length: ${mediaList.length}');
    debugPrint('Première photo dans la liste (carte du dessus): ${mediaList[0].originalPath}');
    if (previousIndex < mediaList.length) {
      debugPrint('Photo à previousIndex ($previousIndex): ${mediaList[previousIndex].originalPath}');
    }
    
    // On se fie au `previousIndex` fourni par CardSwiper.
    // Le bug précédent venait probablement du fait qu'on supprimait toujours l'index 0,
    // ce qui, combiné à un délai, créait une désynchronisation.
    if (previousIndex >= mediaList.length) {
      debugPrint('Swipe ignoré : index $previousIndex hors des limites de la liste (taille ${mediaList.length})');
      return false; // Index hors limites, on annule le swipe.
    }

    final media = mediaList[previousIndex];
    debugPrint('Photo qui sera traitée (index $previousIndex): ${media.originalPath}');
    debugPrint('Swipe détecté - Direction: $direction');

    // Précharger les prochaines images en arrière-plan (non-bloquant)
    if (mediaList.length > previousIndex + 1) {
      // Identifier les 3 prochaines images à précharger
      final nextMediaItems = mediaList.sublist(previousIndex + 1).take(3).toList();
      
      // Précharger en arrière-plan sans bloquer le swipe
      if (nextMediaItems.isNotEmpty) {
        final mediaRepo = ref.read(mediaRepositoryProvider);
        // Fire and forget - ne pas attendre
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
      // Exécuter l'action avec l'index correct
      if (direction == CardSwiperDirection.right) {
        await _onSwipeRight(previousIndex);
      } else if (direction == CardSwiperDirection.left) {
        await _onSwipeLeft(media, previousIndex);
      } else if (direction == CardSwiperDirection.bottom) {
        // Pour le swipe vers le bas (album), on affiche le menu mais on ne supprime pas encore
        // La suppression se fera quand l'utilisateur sélectionnera un album
        await _onSwipeDown(media, previousIndex);
        // Retourner false pour annuler l'animation du swipe
        return false;
      }
        
        // Précharger plus d'images en arrière-plan
        _preloadNextMediaFiles();
        
        // The undo (top swipe) is handled by a separate gesture detector and controller.
        return true;
      } catch (e) {
        debugPrint('Erreur pendant l\'action de swipe: ${e.toString()}');
        return false;
      }
    } finally {
      // Toujours débloquer le flag, même en cas d'erreur
      _isProcessingSwipe = false;
    }
  }

  Future<void> _onSwipeRight(int index) async {
    ref.read(swipeHistoryProvider.notifier).state = null; // No undo for "keep"
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
    ref.read(swipeHistoryProvider.notifier).state = null; // Clear history after undo
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
          // Supprimer l'élément à l'index spécifié
          await ref.read(swipeCardStateProvider.notifier).removeAt(index);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Initialiser l'écran sans forcer un rafraîchissement complet
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Clear any existing cache
      _fileCache.clear();
      _widgetCache.clear();
      
      // Request permissions if needed
      final permissionState = await PhotoManager.requestPermissionExtend();
      if (!permissionState.isAuth) {
        // Show permission dialog if needed
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
          
          // Trigger preload if not already preloading
          if (!_isPreloading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _preloadNextMediaFiles();
            });
          }
          
          return GestureDetector(
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
                    duration: const Duration(milliseconds: 100), // Ultra rapide : 100ms au lieu de 200ms
                    backCardOffset: const Offset(0, 10),
                    scale: 0.98,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    numberOfCardsDisplayed: 3, // Afficher 3 cartes pour l'effet de paquet
                    threshold: 40, // Seuil réduit pour swiper plus facilement
                    isLoop: false,
                    maxAngle: 25, // Angle réduit pour animation plus rapide
                    cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                      // Vérification de sécurité pour éviter les erreurs d'index
                      if (index >= mediaList.length) {
                        debugPrint('Index hors limites: $index >= ${mediaList.length}');
                        return const Center(
                          child: Text('Chargement...', style: TextStyle(color: Colors.white))
                        );
                      }
                      
                      final media = mediaList[index];
                      final file = _fileCache[media.originalPath];
                      
                      // Log pour la carte du dessus uniquement
                      if (index == 0) {
                        debugPrint('Carte du dessus (index 0): ${media.originalPath}');
                      }
                      
                      // Précharger seulement pour la première carte et si pas déjà en cours
                      if (index == 0 && !_isPreloading) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _preloadNextMediaFiles();
                          
                          // Charger plus de médias si nécessaire
                          if (mediaList.length < 10) {
                            final currentList = ref.read(swipeCardStateProvider).value ?? [];
                            if (currentList.isNotEmpty) {
                              ref.read(swipeCardStateProvider.notifier).loadMore();
                            }
                          }
                        });
                      }
                      
                      // Si le fichier n'est pas en cache, le charger
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
                      
                      // Utiliser le cache de widgets pour les cartes en arrière-plan (index > 0)
                      // Cela évite les reconstructions et les saccades
                      if (index > 0 && _widgetCache.containsKey(index)) {
                        return _widgetCache[index]!;
                      }
                      
                      // Construire le widget
                      Widget cardWidget;
                      
                      if (index == 0) {
                        // La première carte est interactive avec ValueListenableBuilder
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
                        // Les cartes en arrière-plan sont statiques
                        cardWidget = MediaCard(
                          mediaFile: file,
                          mediaType: media.mediaType,
                          position: Offset.zero,
                          angle: 0,
                        );
                        
                        // Mettre en cache les cartes en arrière-plan
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