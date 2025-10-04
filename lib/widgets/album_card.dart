import 'dart:io';
import 'package:flutter/material.dart';
import 'package:swipewipe10/models/album.dart';
import 'package:swipewipe10/utils/theme.dart';

class AlbumCard extends StatefulWidget {
  final Album album;
  final VoidCallback? onTap;
  final Future<void> Function(String newName) onNameChanged;

  const AlbumCard({
    super.key,
    required this.album,
    this.onTap,
    required this.onNameChanged,
  });

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard> {
  bool _isEditing = false;
  late TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.album.name);
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _submitName();
    }
  }

  void _submitName() {
    if (_textController.text.isNotEmpty && _textController.text != widget.album.name) {
      widget.onNameChanged(_textController.text);
    }
    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: () {
        setState(() {
          _isEditing = true;
          _focusNode.requestFocus();
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: kColorGreyDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kColorGreyDark.withOpacity(0.5)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // --- Background Image/Thumbnail ---
              if (widget.album.coverPath != null && File(widget.album.coverPath!).existsSync())
                Image.file(
                  File(widget.album.coverPath!),
                  fit: BoxFit.cover,
                  color: Colors.black.withOpacity(0.4), // Apply a dark tint
                  colorBlendMode: BlendMode.darken,
                )
              else
                // Placeholder icon if no cover image
                const Center(child: Icon(Icons.photo_library, color: kColorGreyLight, size: 50)),

              // --- Album Name ---
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: _isEditing ? _buildEditField() : _buildNameDisplay(),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameDisplay() {
    return Text(
      widget.album.name,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildEditField() {
    return Material(
      color: Colors.transparent,
      child: TextField(
        controller: _textController,
        focusNode: _focusNode,
        autofocus: true,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.all(4),
          border: InputBorder.none,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: kColorWhite),
          ),
        ),
        onSubmitted: (_) => _submitName(),
      ),
    );
  }
}