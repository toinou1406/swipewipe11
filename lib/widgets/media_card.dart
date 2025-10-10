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

    if (dx.abs() > dy.abs()) {
      direction = dx > 0 ? SwipeDirection.right : SwipeDirection.left;
    } else {
      direction = dy > 0 ? SwipeDirection.down : SwipeDirection.up;
    }

    Color color;
    String text;

    switch (direction) {
      case SwipeDirection.left:
        color = Colors.red;
        text = 'DELETE';
        break;
      case SwipeDirection.right:
        color = Colors.green;
        text = 'KEEP';
        break;
      case SwipeDirection.up:
        color = Colors.blue;
        text = 'RESTORE';
        break;
      case SwipeDirection.down:
        color = Colors.orange;
        text = 'ALBUM';
        break;
      case SwipeDirection.none:
        return const SizedBox.shrink();
    }

    final opacity = min(position.distance / 150, 0.7);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withOpacity(opacity),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: kColorWhite,
          ),
        ),
      ),
    );
  }
}