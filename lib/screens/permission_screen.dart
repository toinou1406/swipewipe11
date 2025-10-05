import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:swipewipe10/utils/theme.dart';

class PermissionScreen extends StatelessWidget {
  final VoidCallback onPermissionGranted;

  const PermissionScreen({super.key, required this.onPermissionGranted});

  Future<void> _requestPermission(BuildContext context) async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();

    // Check if the widget is still in the tree before showing a dialog.
    if (!context.mounted) return;

    if (ps.hasAccess) {
      onPermissionGranted();
    } else {
      // Show a dialog or a persistent message if permission is denied
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: kColorGreyDark,
          title: Text('Access Denied', style: Theme.of(context).textTheme.displayLarge),
          content: Text(
            'SwipeClean cannot function without access to your photos. Please grant permission in your device settings.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: kColorWhite)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kColorWhite,
                foregroundColor: kColorBlack,
              ),
              onPressed: () {
                PhotoManager.openSetting(); // Opens the app settings
                Navigator.of(context).pop();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.photo_library_outlined, size: 100, color: kColorGreyLight),
            const SizedBox(height: 32),
            Text(
              'Welcome to SwipeClean',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'To help you clean up your gallery, we need access to your photos and videos.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kColorWhite,
                foregroundColor: kColorBlack,
                minimumSize: const Size(double.infinity, 60),
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              onPressed: () => _requestPermission(context),
              child: const Text('Grant Access'),
            ),
          ],
        ),
      ),
    );
  }
}