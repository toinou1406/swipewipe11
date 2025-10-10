import 'dart:io';
import 'package:flutter/material.dart';
import 'package:swipewipe10/utils/theme.dart';

class MediaCard extends StatelessWidget {
  final File mediaFile;
  final String mediaType;

  const MediaCard({
    super.key,
    required this.mediaFile,
    required this.mediaType,
  });

  @override
  Widget build(BuildContext context) {
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
          // Show video icon if applicable
          if (mediaType == 'video')
            const Center(
              child: Icon(Icons.play_circle_outline, color: kColorWhite, size: 80),
            ),
        ],
      ),
    );
  }
}