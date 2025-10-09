import 'dart:io';
import 'package:flutter/material.dart';
import 'package:swipewipe10/utils/theme.dart';

class MediaCard extends StatefulWidget {
  final File mediaFile;
  final String mediaType;
  final bool isTopCard;
  final Function(DragEndDetails) onSwipe;

  const MediaCard({
    super.key,
    required this.mediaFile,
    required this.mediaType,
    required this.isTopCard,
    required this.onSwipe,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  Offset _position = Offset.zero;
  bool _isDragging = false;

  void _onPanStart(DragStartDetails details) {
    if (widget.isTopCard) {
      setState(() {
        _isDragging = true;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (widget.isTopCard) {
      setState(() {
        _position += details.delta;
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (widget.isTopCard) {
      setState(() {
        _isDragging = false;
      });
      // Reset position after swipe to not affect the next card
      _position = Offset.zero;
      widget.onSwipe(details);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: AnimatedContainer(
        duration: Duration(milliseconds: _isDragging ? 0 : 200),
        transform: Matrix4.identity()
          ..translate(_position.dx, _position.dy)
          ..rotateZ(_getRotationAngle()),
        child: _buildCardContent(size),
      ),
    );
  }

  double _getRotationAngle() {
    // Rotate the card slightly as it's dragged
    return _position.dx / (MediaQuery.of(context).size.width / 2) * 0.2;
  }

  Widget _buildCardContent(Size size) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kColorGreyDark, width: 2),
        image: DecorationImage(
          image: FileImage(widget.mediaFile),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          // Show video icon if applicable
          if (widget.mediaType == 'video')
            const Center(
              child: Icon(Icons.play_circle_outline, color: kColorWhite, size: 80),
            ),
          // Show "DELETE" or "KEEP" overlay based on swipe direction
          if (_position.dx.abs() > 20) _buildSwipeOverlay(),
        ],
      ),
    );
  }

  Widget _buildSwipeOverlay() {
    final isSwipingRight = _position.dx > 0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isSwipingRight
            ? Colors.green.withOpacity(0.4)
            : Colors.red.withOpacity(0.4),
      ),
      child: Center(
        child: Text(
          isSwipingRight ? 'KEEP' : 'DELETE',
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