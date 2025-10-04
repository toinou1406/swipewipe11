import 'dart:io';
import 'package:flutter/material.dart';
import 'package:swipewipe10/utils/theme.dart';

class MediaCard extends StatelessWidget {
  final File mediaFile;
  final String mediaType;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeUp;
  final VoidCallback onSwipeDown;

  const MediaCard({
    super.key,
    required this.mediaFile,
    required this.mediaType,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.onSwipeUp,
    required this.onSwipeDown,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! > 0) {
          onSwipeRight(); // Swiped Right
        } else if (details.primaryVelocity! < 0) {
          onSwipeLeft(); // Swiped Left
        }
      },
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! > 0) {
          onSwipeDown(); // Swiped Down
        } else if (details.primaryVelocity! < 0) {
          onSwipeUp(); // Swiped Up
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kColorGreyDark, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // --- Media Display ---
              _buildMediaDisplay(),

              // --- Swipe Indicators ---
              _buildSwipeIndicator(icon: Icons.arrow_back, alignment: Alignment.centerLeft),
              _buildSwipeIndicator(icon: Icons.arrow_forward, alignment: Alignment.centerRight),
              _buildSwipeIndicator(icon: Icons.arrow_upward, alignment: Alignment.topCenter),
              _buildSwipeIndicator(icon: Icons.arrow_downward, alignment: Alignment.bottomCenter),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaDisplay() {
    // Apply a black and white filter to the media
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0,      0,      0,      1, 0,
      ]),
      child: mediaType == 'video'
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.file(mediaFile, fit: BoxFit.cover),
                const Center(
                  child: Icon(Icons.play_circle_outline, color: kColorWhite, size: 80),
                ),
              ],
            )
          : Image.file(mediaFile, fit: BoxFit.cover),
    );
  }

  Widget _buildSwipeIndicator({required IconData icon, required Alignment alignment}) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Icon(
          icon,
          color: kColorWhite.withOpacity(0.2), // Faint indicator
          size: 40,
        ),
      ),
    );
  }
}