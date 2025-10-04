import 'package:flutter/material.dart';
import 'package:swipewipe10/models/album.dart';
import 'package:swipewipe10/utils/theme.dart';

class SwipeMenu extends StatelessWidget {
  final List<Album> albums;
  final Function(int albumId) onAlbumSelected;

  const SwipeMenu({
    super.key,
    required this.albums,
    required this.onAlbumSelected,
  });

  @override
  Widget build(BuildContext context) {
    // We only take the first 3 albums as per the initial request.
    final displayedAlbums = albums.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: kColorOverlay,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add to Album',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: displayedAlbums.map((album) {
                return _buildAlbumIcon(
                  context: context,
                  album: album,
                  icon: _getIconForAlbum(album.name),
                  onTap: () => onAlbumSelected(album.id!),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumIcon({
    required BuildContext context,
    required Album album,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: kColorGreyDark,
            child: Icon(icon, color: kColorWhite, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            album.name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kColorWhite),
          ),
        ],
      ),
    );
  }

  IconData _getIconForAlbum(String albumName) {
    switch (albumName.toLowerCase()) {
      case 'favorites':
        return Icons.favorite_border;
      case 'trips':
        return Icons.airplanemode_active_outlined;
      case 'family':
        return Icons.home_outlined;
      default:
        return Icons.photo_album_outlined;
    }
  }
}