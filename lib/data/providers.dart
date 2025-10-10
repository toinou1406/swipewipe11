import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storage_space/storage_space.dart'; // Replaced disk_space
import 'package:photo_manager/photo_manager.dart';

import 'package:swipewipe10/data/database_helper.dart';
import 'package:swipewipe10/data/media_repository.dart';
import 'package:swipewipe10/models/album.dart';
import 'package:swipewipe10/models/media.dart';

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
  StorageSpace storage = await getStorageSpace;

  return {
    'totalSpace': storage.total.gigabytes,
    'usedSpace': storage.used.gigabytes,
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

final unsortedMediaProvider = FutureProvider<List<Media>>((ref) {
  return ref.watch(databaseHelperProvider).readUnsortedMedia(limit: 50);
});

final permissionStatusProvider = FutureProvider<PermissionState>((ref) async {
  return PhotoManager.requestPermissionExtend();
});

final mediaSyncProvider = FutureProvider<void>((ref) async {
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  await mediaRepo.syncMediaWithDatabase();
});

// --- State Management Notifiers (New Riverpod 2.x+ Syntax) ---

final albumListProvider = AsyncNotifierProvider<AlbumListNotifier, List<Album>>(AlbumListNotifier.new);

class AlbumListNotifier extends AsyncNotifier<List<Album>> {
  @override
  Future<List<Album>> build() async {
    return ref.watch(databaseHelperProvider).readAllAlbums();
  }

  Future<void> updateAlbumName(int id, String newName) async {
    final dbHelper = ref.read(databaseHelperProvider);
    final albums = await dbHelper.readAllAlbums();
    final albumToUpdate = albums.firstWhere((a) => a.id == id);
    await dbHelper.updateAlbum(albumToUpdate.copyWith(name: newName));
    ref.invalidateSelf();
    await future;
  }
}

final swipeCardStateProvider = AsyncNotifierProvider<SwipeNotifier, List<Media>>(SwipeNotifier.new);

class SwipeNotifier extends AsyncNotifier<List<Media>> {
  int _page = 0;
  bool _isLoading = false;
  static const _pageSize = 20;

  @override
  Future<List<Media>> build() async {
    _page = 0;
    return _fetchNextPage();
  }

  Future<List<Media>> _fetchNextPage() async {
    if (_isLoading) return state.value ?? [];
    _isLoading = true;

    final dbHelper = ref.read(databaseHelperProvider);
    final newMedia = await dbHelper.readUnsortedMedia(limit: _pageSize, offset: _page * _pageSize);
    _page++;

    _isLoading = false;
    return newMedia;
  }

  Future<void> loadMore() async {
    final newMedia = await _fetchNextPage();
    if (newMedia.isNotEmpty) {
      state = AsyncData([...state.value!, ...newMedia]);
    }
  }

  void removeFirst() {
    if (state.value != null && state.value!.isNotEmpty) {
      state = AsyncData(state.value!.sublist(1));
      // Pre-fetch if we are getting to the end of the list
      if (state.value!.length < 5) {
        loadMore();
      }
    }
  }

  void undo(Media media) {
     if (state.value != null) {
      state = AsyncData([media, ...state.value!]);
    }
  }
}

final freedSpaceCounterProvider = StateProvider<double>((ref) => 0.0);

// --- Navigation Providers ---
final pageControllerProvider = Provider.autoDispose<PageController>((ref) {
  return PageController(initialPage: 1);
});

final pageIndexProvider = StateProvider.autoDispose<int>((ref) => 1);