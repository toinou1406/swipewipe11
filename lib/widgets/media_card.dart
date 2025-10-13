import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:swipewipe10/utils/theme.dart';

enum SwipeDirection { left, right, up, down, none }

class MediaCard extends StatelessWidget {
  final File mediaFile;
  final String mediaType;
  final double angle;
  final Offset position;

  const MediaCard({
    super.key,
    required this.mediaFile,
    required this.mediaType,
    this.angle = 0,
    this.position = Offset.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: position,
      child: Transform.rotate(
        angle: angle,
        child: _buildCardContent(context),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kColorGreyDark, width: 2),
        image: DecorationImage(
          image: FileImage(mediaFile),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          if (mediaType == 'video')
            const Center(
              child: Icon(Icons.play_circle_outline, color: kColorWhite, size: 80),
            ),
          _buildSwipeOverlay(),
        ],
      ),
    );
  }

  Widget _buildSwipeOverlay() {
    final dx = position.dx;
    final dy = position.dy;
    SwipeDirection direction = SwipeDirection.none;

    // Détermine la direction principale du swipe
    if (dx.abs() > dy.abs()) {
      direction = dx > 0 ? SwipeDirection.right : SwipeDirection.left;
    } else {
      // On ignore le swipe vers le haut et le bas pour les indicateurs
      // car ils sont gérés par d'autres gestes
      if (dy < 0) direction = SwipeDirection.up;
      if (dy > 0) direction = SwipeDirection.down;
    }

    Color color;
    IconData icon;

    switch (direction) {
      case SwipeDirection.left:
        color = Colors.red;
        icon = Icons.close;
        break;
      case SwipeDirection.right:
        color = Colors.green;
        icon = Icons.check;
        break;
      case SwipeDirection.up:
      case SwipeDirection.down:
      case SwipeDirection.none:
        return const SizedBox.shrink(); // Pas d'indicateur pour haut/bas/none
    }

    // Calcule l'opacité en fonction de la distance de swipe
    final opacity = min(position.distance / 150, 0.7);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withOpacity(opacity),
      ),
      child: Center(
        child: Icon(
          icon,
          color: kColorWhite,
          size: 100, // Taille de l'icône augmentée pour être bien visible
        ),
      ),
    );
  }
}