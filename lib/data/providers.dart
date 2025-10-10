import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

final permissionStatusProvider = FutureProvider<PermissionState>((ref) async {
  return PhotoManager.requestPermissionExtend();
});

final mediaSyncProvider = FutureProvider<void>((ref) async {
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  await mediaRepo.syncMediaWithDatabase();
});

// --- State Management Notifiers ---

final swipeCardStateProvider = AsyncNotifierProvider<SwipeNotifier, List<Media>>(SwipeNotifier.new);

class SwipeNotifier extends AsyncNotifier<List<Media>> {
  int _page = 0;
  bool _isLoading = false;
  static const int _pageSize = 20;

  @override
  Future<List<Media>> build() async {
    _page = 0;
    return _fetchNextPage();
  }

  Future<List<Media>> _fetchNextPage() async {
    if (_isLoading) return []; // Prevent concurrent fetches
    _isLoading = true;

    final dbHelper = ref.read(databaseHelperProvider);
    final newMedia = await dbHelper.readUnsortedMedia(limit: _pageSize, offset: _page * _pageSize);
    _page++;

    _isLoading = false;
    return newMedia;
  }

  Future<void> _loadMore() async {
    final newMedia = await _fetchNextPage();
    if (newMedia.isNotEmpty) {
      final currentState = state.value ?? [];
      // --- CRITICAL FIX: Ensure photo uniqueness to prevent duplicates ---
      final currentIds = currentState.map((e) => e.id).toSet();
      final uniqueNewMedia = newMedia.where((e) => !currentIds.contains(e.id)).toList();
      state = AsyncData([...currentState, ...uniqueNewMedia]);
    }
  }

  void removeFirst() {
    final currentList = state.value;
    if (currentList != null && currentList.isNotEmpty) {
      state = AsyncData(currentList.sublist(1));
      // Pre-fetch next page if we are running low on cards
      if (currentList.length < 10) {
        _loadMore();
      }
    }
  }

  void undo(Media media) {
    final currentList = state.value;
     if (currentList != null) {
      state = AsyncData([media, ...currentList]);
    }
  }
}

final freedSpaceCounterProvider = StateProvider<double>((ref) => 0.0);

// --- Navigation Providers ---
final pageControllerProvider = Provider.autoDispose<PageController>((ref) {
  return PageController(initialPage: 1);
});

final pageIndexProvider = StateProvider.autoDispose<int>((ref) => 1);