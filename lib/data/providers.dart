import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storage_space/storage_space.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:swipewipe10/data/database_helper.dart';
import 'package:swipewipe10/data/media_repository.dart';
import 'package:swipewipe10/models/album.dart';
import 'package:swipewipe10/models/media.dart';

// --- Action History Provider ---
class SwipeAction {
  final Media media;
  final String action; // 'delete' or 'album'
  SwipeAction(this.media, this.action);
}
final swipeHistoryProvider = StateProvider<SwipeAction?>((ref) => null);


// --- Database and Repository Providers ---
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository();
});

// --- Asynchronous Data Providers ---
final albumsProvider = FutureProvider<List<Album>>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return dbHelper.readAllAlbums();
});

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final storageStatsProvider = FutureProvider<Map<String, double>>((ref) async {
  // Use the new, more reliable package
  // lowOnSpaceThreshold: 2GB in bytes, fractionDigits: 1 for human-readable values
  StorageSpace storage = await getStorageSpace(
    lowOnSpaceThreshold: 2 * 1024 * 1024 * 1024, // 2GB threshold
    fractionDigits: 1,
  );

  // Convert bytes to gigabytes (1 GB = 1024^3 bytes)
  const bytesPerGigabyte = 1024 * 1024 * 1024;
  
  return {
    'totalSpace': storage.total / bytesPerGigabyte,
    'usedSpace': storage.used / bytesPerGigabyte,
    'freedSpaceThisMonth': 2.3, // Mocked as per original plan
  };
});

final lastVisitedAlbumProvider = FutureProvider<Album?>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final lastVisitedId = prefs.getInt('lastVisitedAlbumId');

  if (lastVisitedId != null) {
    return ref.read(databaseHelperProvider).readAlbum(lastVisitedId);
  }

  final albums = await ref.watch(albumsProvider.future);
  return albums.isNotEmpty ? albums.first : null;
});

final permissionStatusProvider = FutureProvider<PermissionState>((ref) async {
  return PhotoManager.requestPermissionExtend();
});

// --- State Management Notifiers ---

final albumListProvider = AsyncNotifierProvider<AlbumListNotifier, List<Album>>(AlbumListNotifier.new);

class AlbumListNotifier extends AsyncNotifier<List<Album>> {
  @override
  Future<List<Album>> build() async {
    final dbHelper = ref.read(databaseHelperProvider);
    return dbHelper.readAllAlbums();
  }

  Future<void> updateAlbumName(int albumId, String newName) async {
    final dbHelper = ref.read(databaseHelperProvider);
    final currentAlbums = state.value ?? [];
    
    // Find the album to update
    final albumIndex = currentAlbums.indexWhere((album) => album.id == albumId);
    if (albumIndex == -1) return;
    
    final album = currentAlbums[albumIndex];
    final updatedAlbum = album.copyWith(name: newName);
    
    // Update in database
    await dbHelper.updateAlbum(updatedAlbum);
    
    // Update state
    final updatedAlbums = [...currentAlbums];
    updatedAlbums[albumIndex] = updatedAlbum;
    state = AsyncData(updatedAlbums);
  }
}

final swipeCardStateProvider = AsyncNotifierProvider<SwipeNotifier, List<Media>>(SwipeNotifier.new);

class SwipeNotifier extends AsyncNotifier<List<Media>> {
  int _page = 0;
  bool _isLoading = false;
  bool _hasMoreMedia = true; // Flag to track if more media is available
  static const int _pageSize = 50; // Increased page size for better performance
  final Set<String> _loadedPaths = {}; // Track loaded media paths to prevent duplicates

  @override
  Future<List<Media>> build() async {
    _page = 0;
    _isLoading = false;
    _hasMoreMedia = true;
    _loadedPaths.clear();
    
    // Lancer une synchronisation en arrière-plan pour s'assurer que la base de données est à jour
    // sans bloquer le chargement initial.
    ref.read(mediaRepositoryProvider).syncMediaWithDatabase();
    
    // Charger la première page directement depuis la base de données.
    return _fetchNextPage();
  }

  Future<List<Media>> _fetchNextPage() async {
    if (_isLoading || !_hasMoreMedia) return []; // Prevent concurrent fetches or if no more media
    _isLoading = true;

    try {
      final dbHelper = ref.read(databaseHelperProvider);
      // Charger les médias non triés en utilisant la pagination
      final newMedia = await dbHelper.readUnsortedMedia(limit: _pageSize, offset: _page * _pageSize);
      
      // Filtrer les doublons qui pourraient déjà être dans l'état
      final uniqueMedia = newMedia.where((media) => !_loadedPaths.contains(media.originalPath)).toList();
      
      if (uniqueMedia.isNotEmpty) {
        _page++;
        _loadedPaths.addAll(uniqueMedia.map((m) => m.originalPath));
      }
      
      // Si on reçoit moins de médias que la taille de la page, on suppose qu'on est à la fin.
      if (newMedia.length < _pageSize) {
        _hasMoreMedia = false;
      }
      
      return uniqueMedia;
    } catch (e) {
      debugPrint('Error fetching media: ${e.toString()}');
      return [];
    } finally {
      _isLoading = false;
    }
  }

  // Load more media and add to the current state
  Future<void> _loadMore() async {
    if (_isLoading || !_hasMoreMedia) return;
    
    debugPrint('Loading more media...');
    final newMedia = await _fetchNextPage();
    if (newMedia.isNotEmpty) {
      final currentState = state.value ?? [];
      state = AsyncData([...currentState, ...newMedia]);
      debugPrint('Added ${newMedia.length} more items. Total: ${currentState.length + newMedia.length}');
    } else {
      debugPrint('No more media to load from DB, checking for new media on device...');
      // If we've truly run out of media from the DB, try to sync with the device
      ref.read(mediaRepositoryProvider).syncMediaWithDatabase().then((_) {
        // After sync, try to load more again.
        _loadMore();
      });
    }
  }
  
  // Version publique de _loadMore pour pouvoir l'appeler depuis l'extérieur
  Future<void> loadMore() async {
    await _loadMore();
  }

  Future<void> removeAt(int index) async {
    final currentList = state.value;
    if (currentList == null || currentList.isEmpty) {
      // Si la liste est vide, essayer de charger plus de médias
      await _loadMore();
      return;
    }
    
    if (index < 0 || index >= currentList.length) {
      debugPrint('Index hors limites: $index (liste de taille ${currentList.length})');
      return;
    }
    
    try {
      // Sauvegarder l'élément supprimé pour référence
      final removedMedia = currentList[index];
      
      debugPrint('=== SUPPRESSION DEBUG ===');
      debugPrint('Index à supprimer: $index');
      debugPrint('Taille de la liste: ${currentList.length}');
      debugPrint('Élément à supprimer: ${removedMedia.originalPath}');
      debugPrint('Liste AVANT suppression (3 premiers):');
      for (int i = 0; i < currentList.length && i < 3; i++) {
        debugPrint('  [$i]: ${currentList[i].originalPath}');
      }
      
      // Vérifier qu'il y a au moins un élément dans la liste
      if (currentList.length > 1) {
        // Créer une nouvelle liste sans l'élément à l'index spécifié
        final newList = List<Media>.from(currentList);
        newList.removeAt(index);
        
        // Mettre à jour l'état avec la nouvelle liste
        state = AsyncData(newList);
        
        debugPrint('Liste APRÈS suppression (3 premiers):');
        for (int i = 0; i < newList.length && i < 3; i++) {
          debugPrint('  [$i]: ${newList[i].originalPath}');
        }
        debugPrint('=== FIN SUPPRESSION ===');
        
        // Vérifier si nous devons charger plus de médias
        if (newList.length < 10) {
          // Utiliser un délai pour éviter de bloquer l'interface
          Future.delayed(const Duration(milliseconds: 500), () {
            _loadMore();
          });
        }
      } else {
        // Si c'est le dernier élément, vider la liste et charger plus de médias
        state = const AsyncData([]);
        
        // Charger plus de médias immédiatement
        loadMore();
      }
      
      // Enregistrer l'action pour permettre l'annulation
      debugPrint('Élément supprimé: ${removedMedia.originalPath}');
      
    } catch (e) {
      debugPrint('Erreur dans removeAt: ${e.toString()}');
      // En cas d'erreur, essayer de recharger les médias
      refreshMedia();
    }
  }

  Future<void> removeFirst() async {
    // Appeler removeAt avec l'index 0
    await removeAt(0);
  }

  Future<void> undo(Media media) async {
    try {
      final currentList = state.value;
      if (currentList != null) {
        // Vérifier si le média existe déjà dans la liste pour éviter les doublons
        final mediaExists = currentList.any((m) => m.originalPath == media.originalPath);
        
        if (!mediaExists) {
          // S'assurer que nous n'ajoutons pas un doublon lors de l'annulation
          if (!_loadedPaths.contains(media.originalPath)) {
            _loadedPaths.add(media.originalPath);
          }
          
          // Créer une nouvelle liste pour éviter les problèmes de référence
          // Utiliser toList() pour créer une copie complètement nouvelle
          final newList = [media, ...currentList.toList()];
          state = AsyncData(newList);
        }
      } else {
        // Si la liste est null, créer une nouvelle liste avec seulement cet élément
        state = AsyncData([media]);
        
        // Précharger plus de médias en arrière-plan
        Future.delayed(const Duration(milliseconds: 300), () {
          _loadMore();
        });
      }
    } catch (e) {
      debugPrint('Erreur dans undo: ${e.toString()}');
      // En cas d'erreur, essayer de recharger les médias
      refreshMedia();
    }
  }
  
  // Force refresh the media list
  Future<void> refreshMedia() async {
    _page = 0;
    _loadedPaths.clear();
    _isLoading = false;
    _hasMoreMedia = true;
    state = const AsyncLoading();
    
    try {
      // Pour un rafraîchissement, on utilise directement le dbHelper
      final dbHelper = ref.read(databaseHelperProvider);
      
      // Charger rapidement les médias initiaux
      final initialMedia = await dbHelper.readUnsortedMedia(limit: _pageSize);
      
      // Mettre à jour les compteurs
      _page = 1;
      
      // Enregistrer les chemins pour éviter les doublons
      for (final media in initialMedia) {
        _loadedPaths.add(media.originalPath);
      }
      
      state = AsyncData(initialMedia);
      
      // Précharger plus de médias en arrière-plan
      if (initialMedia.length < _pageSize * 2) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _loadMore();
        });
      }
    } catch (e) {
      debugPrint('Error refreshing media: ${e.toString()}');
      state = AsyncError(e, StackTrace.current);
    }
  }
}

final freedSpaceCounterProvider = StateProvider<double>((ref) => 0.0);

// --- Navigation Providers ---
final pageControllerProvider = Provider.autoDispose<PageController>((ref) {
  return PageController(initialPage: 1);
});

final pageIndexProvider = StateProvider.autoDispose<int>((ref) => 1);