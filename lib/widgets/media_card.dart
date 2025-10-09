import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:swipewipe10/utils/theme.dart';

enum SwipeDirection { left, right, up, down, none }

class MediaCard extends StatefulWidget {
  final File mediaFile;
  final String mediaType;
  final bool isTopCard;
  final Function(SwipeDirection) onSwiped;

  const MediaCard({
    super.key,
    required this.mediaFile,
    required this.mediaType,
    required this.isTopCard,
    required this.onSwiped,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _animation;
  Offset _position = Offset.zero;
  SwipeDirection _swipeDirection = SwipeDirection.none;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.isTopCard) return;
    _animationController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.isTopCard) return;
    setState(() {
      _position += details.delta;
      _updateSwipeDirection();
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.isTopCard) return;
    final velocity = details.primaryVelocity ?? 0;

    if (velocity.abs() < 500 && _position.distance < 100) {
      // Not a strong enough swipe, animate back to center
      _animateCardBack();
      return;
    }

    // Animate card off-screen
    _animateCardOut(_swipeDirection, velocity);
  }

  void _updateSwipeDirection() {
    if (_position.dx.abs() > _position.dy.abs()) {
      _swipeDirection = _position.dx > 0 ? SwipeDirection.right : SwipeDirection.left;
    } else {
      _swipeDirection = _position.dy > 0 ? SwipeDirection.down : SwipeDirection.up;
    }
  }

  void _animateCardBack() {
    _animation = Tween<Offset>(begin: _position, end: Offset.zero)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _animationController.forward().then((_) {
      setState(() {
        _position = Offset.zero;
        _swipeDirection = SwipeDirection.none;
      });
      _animationController.reset();
    });
  }

  void _animateCardOut(SwipeDirection direction, double velocity) {
    final screenSize = MediaQuery.of(context).size;
    Offset endPosition;

    switch (direction) {
      case SwipeDirection.left:
        endPosition = Offset(-screenSize.width, _position.dy);
        break;
      case SwipeDirection.right:
        endPosition = Offset(screenSize.width, _position.dy);
        break;
      case SwipeDirection.up:
        endPosition = Offset(_position.dx, -screenSize.height);
        break;
      case SwipeDirection.down:
        endPosition = Offset(_position.dx, screenSize.height);
        break;
      case SwipeDirection.none:
        _animateCardBack();
        return;
    }

    _animation = Tween<Offset>(begin: _position, end: endPosition)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    _animationController.forward().then((_) {
      widget.onSwiped(direction);
    });
  }

  double get _rotationAngle => _position.dx / (MediaQuery.of(context).size.width / 2) * 0.2;
  Offset get _currentPosition => _animationController.isAnimating ? _animation.value : _position;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _currentPosition,
      child: Transform.rotate(
        angle: _rotationAngle,
        child: _buildCardContent(),
      ),
    );
  }

  Widget _buildCardContent() {
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
          if (widget.mediaType == 'video')
            const Center(
              child: Icon(Icons.play_circle_outline, color: kColorWhite, size: 80),
            ),
          if (_position.distance > 20) _buildSwipeOverlay(),
        ],
      ),
    );
  }

  Widget _buildSwipeOverlay() {
    Color color;
    String text;

    switch (_swipeDirection) {
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

    final opacity = min(_position.distance / 150, 0.6);

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