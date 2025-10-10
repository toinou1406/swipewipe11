import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:swipewipe10/data/providers.dart';
import 'package:swipewipe10/screens/main_navigation_view.dart';
import 'package:swipewipe10/screens/permission_screen.dart';
import 'package:swipewipe10/utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: SwipeCleanApp(),
    ),
  );
}

class SwipeCleanApp extends ConsumerWidget {
  const SwipeCleanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'SwipeClean',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: const AppStartupWrapper(),
    );
  }
}

// This wrapper widget handles the entire startup flow:
// 1. Check for permissions
// 2. If granted, sync media
// 3. If synced, show main app
class AppStartupWrapper extends ConsumerWidget {
  const AppStartupWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionStatus = ref.watch(permissionStatusProvider);

    return permissionStatus.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error checking permissions: $err'))),
      data: (permission) {
        // Check if permission grants access (authorized or limited)
        if (permission.hasAccess) {
          // If permission is granted, move to the media sync phase
          return const MediaSyncWrapper();
        } else {
          // Otherwise, show the permission request screen
          return PermissionScreen(
            onPermissionGranted: () {
              // When permission is granted from the screen, we refresh the provider
              // to re-trigger this build method and move to the MediaSyncWrapper.
              ref.invalidate(permissionStatusProvider);
            },
          );
        }
      },
    );
  }
}

class MediaSyncWrapper extends ConsumerWidget {
  const MediaSyncWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaSync = ref.watch(mediaSyncProvider);

    return mediaSync.when(
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Syncing your media...'),
            ],
          ),
        ),
      ),
      error: (err, stack) => Scaffold(
        body: Center(
          child: Text('Error syncing media: $err'),
        ),
      ),
      // When sync is complete, show the main app
      data: (_) => const MainNavigationView(),
    );
  }
}