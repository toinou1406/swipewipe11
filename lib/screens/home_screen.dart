import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swipewipe10/data/providers.dart';
import 'package:swipewipe10/utils/theme.dart';
import 'package:swipewipe10/widgets/storage_bar.dart';
import 'package:swipewipe10/widgets/album_card.dart'; // We can reuse the album card for a consistent look

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageStatsAsync = ref.watch(storageStatsProvider);
    final lastVisitedAlbumAsync = ref.watch(lastVisitedAlbumProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Storage Stats ---
            Text(
              'Storage Overview',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 16),
            storageStatsAsync.when(
              data: (stats) => Column(
                children: [
                  StorageBar(
                    label: 'Device Storage',
                    value: stats['usedSpace']! / stats['totalSpace']!,
                    valueLabel: '${stats['usedSpace']!.toStringAsFixed(1)} / ${stats['totalSpace']!.toStringAsFixed(1)} GB',
                  ),
                  const SizedBox(height: 16),
                  StorageBar(
                    label: 'Freed up this month',
                    value: stats['freedSpaceThisMonth']! / stats['totalSpace']!,
                    valueLabel: '+ ${stats['freedSpaceThisMonth']} GB',
                    barColor: kColorGreyLight,
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
            const SizedBox(height: 32),

            // --- Last Visited Album ---
            Text(
              'Last Visited Album',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 16),
            lastVisitedAlbumAsync.when(
              data: (album) {
                if (album == null) {
                  return const Text('No albums available yet.');
                }
                // We reuse the AlbumCard for a consistent UI.
                // We pass a dummy function for onNameChanged as we don't want to edit it here.
                return SizedBox(
                  height: 150,
                  child: AlbumCard(album: album, onNameChanged: (_) async {}),
                );
              },
              loading: () => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
              error: (err, stack) => SizedBox(height: 150, child: Center(child: Text('Error: $err'))),
            ),
            const SizedBox(height: 32),

            // --- Action Buttons ---
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kColorWhite,
                foregroundColor: kColorBlack,
                minimumSize: const Size(double.infinity, 60),
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              onPressed: () {
                // Navigate to Swipe Screen (index 2)
                ref.read(pageControllerProvider).animateToPage(
                      2,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
              },
              child: const Text('Start Cleaning'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: kColorGreyLight,
                side: const BorderSide(color: kColorGreyDark),
                minimumSize: const Size(double.infinity, 50),
                textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kColorGreyLight),
              ),
              onPressed: () {
                // Navigate to Albums Screen (index 0)
                ref.read(pageControllerProvider).animateToPage(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
              },
              child: const Text('View Albums'),
            ),
          ],
        ),
      ),
    );
  }
}