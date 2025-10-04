import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swipewipe10/data/providers.dart';
import 'package:swipewipe10/models/album.dart';
import 'package:swipewipe10/utils/theme.dart';
import 'package:swipewipe10/screens/swipe_album_screen.dart';
import 'package:swipewipe10/widgets/album_card.dart';

class AlbumsScreen extends ConsumerWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsyncValue = ref.watch(albumListProvider);

    return Scaffold(
      body: albumsAsyncValue.when(
        data: (albums) => _buildAlbumGrid(context, albums, ref),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildAlbumGrid(BuildContext context, List<Album> albums, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1, // Creates square cards
        ),
        itemCount: albums.length + 1, // +1 for the premium button
        itemBuilder: (context, index) {
          if (index == albums.length) {
            return _buildAddAlbumButton();
          }
          final album = albums[index];
          return AlbumCard(
            album: album,
            onNameChanged: (newName) async {
              await ref.read(albumListProvider.notifier).updateAlbumName(album.id!, newName);
            },
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SwipeAlbumScreen(albumId: album.id!),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAddAlbumButton() {
    return Tooltip(
      message: 'Available in Premium',
      child: Container(
        decoration: BoxDecoration(
          color: kColorBlack,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kColorGreyDark),
        ),
        child: const Center(
          child: Icon(
            Icons.add,
            color: kColorGreyDark,
            size: 60,
          ),
        ),
      ),
    );
  }
}