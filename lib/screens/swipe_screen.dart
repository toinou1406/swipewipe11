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

  bool _isProcessingSwipe = false; // Flag pour éviter les swipes multiples simultanés

  @override
  void dispose() {
    _swiperController.dispose();
    _dragPosition.dispose();
    super.dispose();
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

    // IMPORTANT: Après analyse des logs, le previousIndex du CardSwiper ne correspond PAS
    // à l'index dans notre liste de données. La carte swipée est TOUJOURS à l'index 0.
    // Le previousIndex semble être un compteur interne du CardSwiper.
    final media = mediaList[0];
    debugPrint('Photo qui sera supprimée (index 0): ${media.originalPath}');

    debugPrint('Swipe détecté - Direction: $direction, Media sélectionné: ${media.originalPath}');

      try {
        // Exécuter l'action immédiatement sans délai
        // Toujours utiliser l'index 0 car la carte swipée est toujours au sommet de la pile
        if (direction == CardSwiperDirection.right) {
          await _onSwipeRight(0);
        } else if (direction == CardSwiperDirection.left) {
          await _onSwipeLeft(media, 0);
        } else if (direction == CardSwiperDirection.bottom) {
          // Pour le swipe vers le bas (album), on affiche le menu mais on ne supprime pas encore
          // La suppression se fera quand l'utilisateur sélectionnera un album
          await _onSwipeDown(media, 0);
          // Retourner false pour annuler l'animation du swipe
          return false;
        }
        
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
                      ref.read(swipeCardStateProvider.notifier).refreshMedia();
                    },
                    child: const Text('Rechercher de nouvelles photos'),
                  ),
                ],
              ),
            );
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
                        return const Center(child: Text('Chargement...', style: TextStyle(color: Colors.white)));
                      }
                      
                      final media = mediaList[index];
                      final mediaRepo = ref.read(mediaRepositoryProvider);

                      // Utiliser un FutureBuilder pour gérer le chargement de chaque carte
                      return FutureBuilder<File?>(
                        // La clé est essentielle pour que Flutter reconstruise le FutureBuilder
                        // uniquement lorsque l'objet média change
                        key: ValueKey(media.id),
                        future: mediaRepo.getFileForMedia(media),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            // Afficher un indicateur de chargement pendant que le fichier est récupéré
                            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                          }

                          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                            // Afficher un message d'erreur si le chargement échoue
                            return const Center(child: Text('Erreur de chargement', style: TextStyle(color: Colors.white)));
                          }

                          final file = snapshot.data!;

                          // La première carte (au-dessus) est interactive
                          if (index == 0) {
                            return ValueListenableBuilder<Offset>(
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
                            return MediaCard(
                              mediaFile: file,
                              mediaType: media.mediaType,
                              position: Offset.zero,
                              angle: 0,
                            );
                          }
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