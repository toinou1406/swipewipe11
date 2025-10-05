import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:disk_space/disk_space.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:swipewipe10/data/database_helper.dart';
import 'package:swipewipe10/data/media_repository.dart';
import 'package:swipewipe10/models/album.dart';
import 'package:swipewipe10/models/media.dart';


// Provider for the DatabaseHelper instance
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

// Provider to get the list of all albums from the database
final albumsProvider = FutureProvider<List<Album>>((ref) async {
  final dbHelper = ref.watch(databaseHelperProvider);
  return dbHelper.readAllAlbums();
});

// Notifier provider to allow for updating the list of albums
final albumListProvider = StateNotifierProvider<AlbumListNotifier, AsyncValue<List<Album>>>((ref) {
  return AlbumListNotifier(ref);
});

class AlbumListNotifier extends StateNotifier<AsyncValue<List<Album>>> {
  final Ref _ref;

  AlbumListNotifier(this._ref) : super(const AsyncValue.loading()) {
    _fetchAlbums();
  }

  Future<void> _fetchAlbums() async {
    state = const AsyncValue.loading();
    try {
      final dbHelper = _ref.read(databaseHelperProvider);
      final albums = await dbHelper.readAllAlbums();
      state = AsyncValue.data(albums);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateAlbumName(int id, String newName) async {
    final dbHelper = _ref.read(databaseHelperProvider);
    final currentState = state.value;
    if (currentState == null) return;

    final albumToUpdate = currentState.firstWhere((a) => a.id == id);
    await dbHelper.updateAlbum(albumToUpdate.copyWith(name: newName));

    // Refresh the list from the database to ensure consistency
    await _fetchAlbums();
  }

  Future<void> refresh() async {
    await _fetchAlbums();
  }
}

// --- Home Screen Providers ---

// Provider for SharedPreferences
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

// Provider for actual storage stats
final storageStatsProvider = FutureProvider<Map<String, double>>((ref) async {
  final double totalSpace = await DiskSpace.getTotalDiskSpace ?? 0.0;
  final double freeSpace = await DiskSpace.getFreeDiskSpace ?? 0.0;
  final double usedSpace = totalSpace - freeSpace;

  // Freed space is still mocked as we don't have a persistent way to track it month over month yet
  return {
    'totalSpace': totalSpace / 1024, // Convert MB to GB
    'usedSpace': usedSpace / 1024, // Convert MB to GB
    'freedSpaceThisMonth': 2.3, // GB (Mocked)
  };
});

// Provider for the last visited album
final lastVisitedAlbumProvider = FutureProvider<Album?>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final lastVisitedId = prefs.getInt('lastVisitedAlbumId');

  if (lastVisitedId != null) {
    final dbHelper = ref.read(databaseHelperProvider);
    return dbHelper.readAlbum(lastVisitedId);
  }

  // As per instructions, if no album has been visited, return the first default album
  final albums = await ref.watch(albumsProvider.future);
  return albums.isNotEmpty ? albums.first : null;
});

// --- Swipe Screen Providers ---

final unsortedMediaProvider = FutureProvider<List<Media>>((ref) async {
  final dbHelper = ref.read(databaseHelperProvider);
  // Initially, we can load some media. This can be expanded with pagination later.
  return dbHelper.readUnsortedMedia(limit: 50);
});

final swipeCardStateProvider = StateNotifierProvider<SwipeCardNotifier, List<Media>>((ref) {
  final unsortedMedia = ref.watch(unsortedMediaProvider);
  return SwipeCardNotifier(unsortedMedia.value ?? []);
});

class SwipeCardNotifier extends StateNotifier<List<Media>> {
  SwipeCardNotifier(super.initialMedia);

  void removeCard() {
    if (state.isNotEmpty) {
      state = List.from(state)..removeAt(0);
    }
  }

  void undo(Media lastMedia) {
    state = [lastMedia, ...state];
  }
}

// Provider for the session's freed space counter
final freedSpaceCounterProvider = StateProvider<double>((ref) => 0.0);

// --- Media Repository and Sync ---

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository();
});

// This provider will trigger the media sync on app startup
final mediaSyncProvider = FutureProvider<void>((ref) async {
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  // We don't want to block the UI for too long, so this runs in the background.
  // The UI can decide to show a loading state based on this provider.
  await mediaRepo.syncMediaWithDatabase();
});

// --- Permission Provider ---

final permissionStatusProvider = FutureProvider<PermissionState>((ref) async {
  return await PhotoManager.requestPermissionExtend();
});

// --- Navigation Providers ---

final pageControllerProvider = Provider.autoDispose<PageController>((ref) {
  return PageController(initialPage: 1);
});

final pageIndexProvider = StateProvider.autoDispose<int>((ref) => 1);