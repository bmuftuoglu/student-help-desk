import 'dart:io';
import 'package:flutter/material.dart';
import '../../../constants/app_constants.dart';

class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onCameraTap;
  final VoidCallback? onGalleryTap;
  final VoidCallback? onFileTap;
  final String? attachedFilePath;
  final String? attachedFileName;
  final String? attachedMimeType;
  final VoidCallback? onRemoveAttachment;

  const MessageInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.onCameraTap,
    this.onGalleryTap,
    this.onFileTap,
    this.attachedFilePath,
    this.attachedFileName,
    this.attachedMimeType,
    this.onRemoveAttachment,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  bool _showButtons = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() => _showButtons = false);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleButtons() {
    if (_showButtons) {
      _animationController.reverse();
    } else {
      setState(() => _showButtons = true);
      _animationController.forward(from: 0);
    }
  }

  bool get _hasAttachment =>
      widget.attachedFilePath != null && widget.attachedFilePath!.isNotEmpty;

  bool get _isImage =>
      widget.attachedMimeType?.startsWith('image/') ?? false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
        vertical: 6,
      ),
      color: isDarkMode ? Colors.black : Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showButtons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _menuButton(
                        icon: Icons.camera_alt,
                        label: 'Kamera',
                        isDarkMode: isDarkMode,
                        onTap: () {
                          widget.onCameraTap?.call();
                          _toggleButtons();
                        },
                      ),
                      const SizedBox(width: 8),
                      _menuButton(
                        icon: Icons.photo_library,
                        label: 'Galeri',
                        isDarkMode: isDarkMode,
                        onTap: () {
                          widget.onGalleryTap?.call();
                          _toggleButtons();
                        },
                      ),
                      const SizedBox(width: 8),
                      _menuButton(
                        icon: Icons.attach_file,
                        label: 'Dosya',
                        isDarkMode: isDarkMode,
                        onTap: () {
                          widget.onFileTap?.call();
                          _toggleButtons();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_hasAttachment)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color.fromARGB(80, 31, 41, 55)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(widget.attachedFilePath!),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.grey[800]
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _fileIcon(widget.attachedMimeType),
                        size: 28,
                        color: _fileIconColor(widget.attachedMimeType),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.attachedFileName ?? '1 dosya eklendi',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: widget.onRemoveAttachment,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _toggleButtons,
                icon: Icon(
                  Icons.add,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: isDarkMode
                      ? const Color.fromARGB(57, 35, 35, 35)
                      : Colors.grey[200],
                  minimumSize: const Size(40, 40),
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  minLines: 1,
                  maxLines: 3,
                  keyboardType: TextInputType.multiline,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask anything',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                    ),
                    filled: true,
                    fillColor: isDarkMode
                        ? const Color.fromARGB(57, 35, 35, 35)
                        : Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          AppConstants.defaultBorderRadius),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 13),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: IconButton(
                        onPressed: widget.onSend,
                        icon: Icon(
                          Icons.arrow_upward_rounded,
                          color: isDarkMode ? Colors.black : Colors.white,
                          size: 20,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              isDarkMode ? Colors.white : Colors.grey[900],
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(32, 32),
                        ),
                      ),
                    ),
                  ),
                  onSubmitted: (_) => widget.onSend(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _fileIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('word') || mimeType.contains('msword')) {
      return Icons.description;
    }
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      return Icons.table_chart;
    }
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
      return Icons.slideshow;
    }
    return Icons.insert_drive_file;
  }

  Color _fileIconColor(String? mimeType) {
    if (mimeType == null) return Colors.grey;
    if (mimeType.contains('pdf')) return Colors.red;
    if (mimeType.contains('word') || mimeType.contains('msword')) {
      return Colors.blue;
    }
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      return Colors.green;
    }
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
      return Colors.orange;
    }
    return Colors.grey;
  }

  Widget _menuButton({
    required IconData icon,
    required String label,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon,
          color: isDarkMode ? Colors.white : Colors.black, size: 20),
      label: Text(
        label,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: isDarkMode
            ? const Color.fromARGB(125, 35, 35, 35)
            : Colors.grey[200],
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: Size.zero,
      ),
    );
  }
}
